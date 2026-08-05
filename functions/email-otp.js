const { onCall } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const crypto = require('crypto');
const { sendEmail } = require('./email-service');

// Declared so the RESEND_API_KEY secret is injected into process.env for the
// functions below. Set it once with:
//   firebase functions:secrets:set RESEND_API_KEY
const RESEND_API_KEY = defineSecret('RESEND_API_KEY');

const OTP_TTL_MS = 10 * 60 * 1000; // Code expires after 10 minutes.
const RESEND_COOLDOWN_MS = 60 * 1000; // 60s between emails to the same address.
const MAX_ATTEMPTS = 5; // Incorrect tries before the code is invalidated.
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

/** Deterministic document id for an email address (privacy: no raw email in the doc id). */
function _docIdForEmail(email) {
  return crypto
    .createHash('sha256')
    .update(email.trim().toLowerCase())
    .digest('hex');
}

function _generateOtp() {
  return crypto.randomInt(0, 1000000).toString().padStart(6, '0');
}

function _hashOtp(otp, salt) {
  return crypto.createHash('sha256').update(`${salt}:${otp}`).digest('hex');
}

/**
 * Sends a 6-digit OTP email to the given address (via Resend) and stores the
 * hashed code so it can be verified later. Callable so the signup screen can
 * use it before an account exists.
 */
exports.sendEmailOtp = onCall(
  { secrets: [RESEND_API_KEY] },
  async (request) => {
    const email = (request.data?.email ?? '').toString().trim().toLowerCase();
    if (!EMAIL_RE.test(email)) {
      return { ok: false, error: 'Please enter a valid email address.' };
    }

    const docRef = admin
      .firestore()
      .collection('email_otps')
      .doc(_docIdForEmail(email));
    const existing = (await docRef.get()).data();

    // Rate-limit: one email per address per cooldown window.
    if (existing) {
      const lastSent = existing.createdAt?.toMillis?.() ?? 0;
      const waitMs = RESEND_COOLDOWN_MS - (Date.now() - lastSent);
      if (waitMs > 0) {
        return {
          ok: false,
          error: `Please wait ${Math.ceil(waitMs / 1000)}s before requesting another code.`,
        };
      }
    }

    const otp = _generateOtp();
    const salt = crypto.randomBytes(8).toString('hex');
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      Date.now() + OTP_TTL_MS,
    );

    // Send BEFORE persisting: if Resend rejects the send (missing key / sandbox
    // sender), no record exists and the cooldown doesn't block a retry.
    await sendEmail({
      to: email,
      subject: 'Your NexMeet verification code',
      html: `<p>Your NexMeet email verification code is:</p>
             <h2 style="letter-spacing:6px;color:#7A432D;">${otp}</h2>
             <p>This code expires in 10 minutes. If you didn't request it, you can ignore this email.</p>`,
    });

    await docRef.set({
      codeHash: _hashOtp(otp, salt),
      salt,
      expiresAt,
      attempts: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { ok: true, resendInSeconds: RESEND_COOLDOWN_MS / 1000 };
  },
);

/**
 * Checks a submitted OTP against the stored (hashed) code, enforcing expiry
 * and an attempt limit. Deletes the code once verified or exhausted.
 */
exports.verifyEmailOtp = onCall(async (request) => {
  const email = (request.data?.email ?? '').toString().trim().toLowerCase();
  const code = (request.data?.code ?? '').toString().trim();
  if (!EMAIL_RE.test(email) || !/^\d{6}$/.test(code)) {
    return { ok: false, error: 'Invalid request.' };
  }

  const docRef = admin
    .firestore()
    .collection('email_otps')
    .doc(_docIdForEmail(email));
  const doc = await docRef.get();
  const data = doc.data();
  if (!data) {
    return {
      ok: false,
      error: 'No code was requested for this email. Tap Resend OTP.',
    };
  }

  const expiresAt = data.expiresAt?.toMillis?.() ?? 0;
  if (expiresAt < Date.now()) {
    await docRef.delete();
    return {
      ok: false,
      error: 'This code has expired. Tap Resend OTP for a new one.',
    };
  }

  if ((data.attempts ?? 0) >= MAX_ATTEMPTS) {
    await docRef.delete();
    return {
      ok: false,
      error: 'Too many incorrect attempts. Tap Resend OTP for a new code.',
    };
  }

  if (_hashOtp(code, data.salt) !== data.codeHash) {
    await docRef.update({
      attempts: admin.firestore.FieldValue.increment(1),
    });
    return { ok: false, error: 'Incorrect code. Please try again.' };
  }

  await docRef.delete();
  return { ok: true };
});
