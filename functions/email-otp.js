const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const crypto = require('crypto');
const { sendEmail } = require('./email-service');

const RESEND_API_KEY = defineSecret('RESEND_API_KEY');

const OTP_TTL_MS = 10 * 60 * 1000;
const RESEND_COOLDOWN_MS = 60 * 1000;
const MAX_ATTEMPTS = 5;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

/** CORS headers to allow Flutter Web to call these functions directly */
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Content-Type': 'application/json',
};

function _docIdForEmail(email) {
  return crypto.createHash('sha256').update(email.trim().toLowerCase()).digest('hex');
}

function _generateOtp() {
  return crypto.randomInt(0, 1000000).toString().padStart(6, '0');
}

function _hashOtp(otp, salt) {
  return crypto.createHash('sha256').update(`${salt}:${otp}`).digest('hex');
}

/**
 * Sends a 6-digit OTP email to the given address via Resend.
 * Called as a raw HTTP POST from Flutter to avoid dart2js Int64 issues.
 */
exports.sendEmailOtp = onRequest(
  { secrets: [RESEND_API_KEY], cors: true },
  async (req, res) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
      res.set(CORS_HEADERS).status(204).send('');
      return;
    }

    res.set(CORS_HEADERS);

    if (req.method !== 'POST') {
      res.status(405).json({ ok: false, error: 'Method not allowed' });
      return;
    }

    // Support both direct JSON body and Firebase callable wrapper format
    const body = req.body?.data ?? req.body ?? {};
    const email = (body.email ?? '').toString().trim().toLowerCase();

    if (!EMAIL_RE.test(email)) {
      res.status(200).json({ result: { ok: false, error: 'Please enter a valid email address.' } });
      return;
    }

    // Uniqueness check: verify if email is already registered to another user
    const usersWithEmail = await admin.firestore().collection('users').where('email', '==', email).limit(1).get();
    if (!usersWithEmail.empty) {
      res.status(200).json({ result: { ok: false, error: 'This email address is already registered with another account.' } });
      return;
    }

    const docRef = admin.firestore().collection('email_otps').doc(_docIdForEmail(email));
    const existing = (await docRef.get()).data();

    if (existing) {
      const lastSent = existing.createdAt?.toMillis?.() ?? 0;
      const waitMs = RESEND_COOLDOWN_MS - (Date.now() - lastSent);
      if (waitMs > 0) {
        res.status(200).json({
          result: { ok: false, error: `Please wait ${Math.ceil(waitMs / 1000)}s before requesting another code.` },
        });
        return;
      }
    }

    const otp = _generateOtp();
    const salt = crypto.randomBytes(8).toString('hex');
    const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + OTP_TTL_MS);

    try {
      await sendEmail({
        to: email,
        subject: 'Your NexMeet verification code',
        html: `<p>Your NexMeet email verification code is:</p>
               <h2 style="letter-spacing:6px;color:#7A432D;">${otp}</h2>
               <p>This code expires in 10 minutes. If you didn't request it, you can ignore this email.</p>`,
      });
    } catch (e) {
      res.status(200).json({ result: { ok: false, error: e.message } });
      return;
    }

    await docRef.set({
      codeHash: _hashOtp(otp, salt),
      salt,
      expiresAt,
      attempts: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Return resendInSeconds as a string to avoid Int64 issues on Flutter Web
    res.status(200).json({ result: { ok: true, resendInSeconds: '60' } });
  },
);

/**
 * Verifies a submitted OTP against the stored hashed code.
 */
exports.verifyEmailOtp = onRequest(
  { cors: true },
  async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.set(CORS_HEADERS).status(204).send('');
      return;
    }

    res.set(CORS_HEADERS);

    if (req.method !== 'POST') {
      res.status(405).json({ result: { ok: false, error: 'Method not allowed' } });
      return;
    }

    const body = req.body?.data ?? req.body ?? {};
    const email = (body.email ?? '').toString().trim().toLowerCase();
    const code = (body.code ?? '').toString().trim();

    if (!EMAIL_RE.test(email) || !/^\d{6}$/.test(code)) {
      res.status(200).json({ result: { ok: false, error: 'Invalid request.' } });
      return;
    }

    const docRef = admin.firestore().collection('email_otps').doc(_docIdForEmail(email));
    const doc = await docRef.get();
    const data = doc.data();

    if (!data) {
      res.status(200).json({ result: { ok: false, error: 'No code was requested for this email. Tap Resend OTP.' } });
      return;
    }

    const expiresAt = data.expiresAt?.toMillis?.() ?? 0;
    if (expiresAt < Date.now()) {
      await docRef.delete();
      res.status(200).json({ result: { ok: false, error: 'This code has expired. Tap Resend OTP for a new one.' } });
      return;
    }

    if ((data.attempts ?? 0) >= MAX_ATTEMPTS) {
      await docRef.delete();
      res.status(200).json({ result: { ok: false, error: 'Too many incorrect attempts. Tap Resend OTP for a new code.' } });
      return;
    }

    if (_hashOtp(code, data.salt) !== data.codeHash) {
      await docRef.update({ attempts: admin.firestore.FieldValue.increment(1) });
      res.status(200).json({ result: { ok: false, error: 'Incorrect code. Please try again.' } });
      return;
    }

    await docRef.delete();
    res.status(200).json({ result: { ok: true } });
  },
);
