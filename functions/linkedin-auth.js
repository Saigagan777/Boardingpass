/**
 * LinkedIn OAuth 2.0 Authorization Code + PKCE exchange (server-side).
 *
 * Flutter only sends: code, code_verifier, redirect_uri, optional nonce.
 * This function holds the client secret, talks to LinkedIn, creates/links the
 * Firebase user, and returns a Firebase Custom Token. LinkedIn tokens never
 * leave the server (optionally stored encrypted for full-logout revoke).
 */

const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret, defineString } = require('firebase-functions/params');
const admin = require('firebase-admin');
const crypto = require('crypto');
const logger = require('firebase-functions/logger');

const LINKEDIN_CLIENT_SECRET = defineSecret('LINKEDIN_CLIENT_SECRET');
const LINKEDIN_CLIENT_ID = defineString('LINKEDIN_CLIENT_ID', {
  default: '86ltub3ua1c8o4',
});

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Content-Type': 'application/json',
};

/** Production redirect URIs registered in the LinkedIn Developer Portal. */
function allowedRedirectUris() {
  const hosting = [
    'https://fir-p-57bdc.web.app/oauth/linkedin/callback',
    'https://fir-p-57bdc.firebaseapp.com/oauth/linkedin/callback',
  ];
  // Web SPA origins (LinkedIn redirects straight back to the app on web).
  const spa = [
    'https://fir-p-57bdc.web.app',
    'https://fir-p-57bdc.firebaseapp.com',
    'http://localhost',
    'http://localhost:5000',
    'http://localhost:8080',
    'http://127.0.0.1:5000',
    'http://127.0.0.1:8080',
  ];
  return new Set([...hosting, ...spa]);
}

function isAllowedRedirectUri(uri) {
  if (!uri || typeof uri !== 'string') return false;
  const trimmed = uri.trim();
  if (allowedRedirectUris().has(trimmed)) return true;
  // Allow any localhost / 127.0.0.1 origin for local Flutter web (exact port).
  try {
    const parsed = new URL(trimmed);
    if (
      (parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1') &&
      (parsed.protocol === 'http:' || parsed.protocol === 'https:')
    ) {
      // Reject path-bearing URIs unless they are the fixed mobile callback.
      if (parsed.pathname === '/' || parsed.pathname === '') return true;
    }
  } catch (_) {
    return false;
  }
  return false;
}

function applyCors(res) {
  res.set(CORS_HEADERS);
}

function parseBody(req) {
  return req.body?.data ?? req.body ?? {};
}

function encryptToken(plaintext, keyMaterial) {
  if (!plaintext || !keyMaterial) return null;
  // Expect 64 hex chars (32 bytes) or use SHA-256 of the provided secret.
  const key =
    /^[0-9a-fA-F]{64}$/.test(keyMaterial)
      ? Buffer.from(keyMaterial, 'hex')
      : crypto.createHash('sha256').update(keyMaterial).digest();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const enc = Buffer.concat([cipher.update(String(plaintext), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${iv.toString('hex')}:${tag.toString('hex')}:${enc.toString('hex')}`;
}

function decryptToken(payload, keyMaterial) {
  if (!payload || !keyMaterial) return null;
  const [ivHex, tagHex, dataHex] = String(payload).split(':');
  if (!ivHex || !tagHex || !dataHex) return null;
  const key =
    /^[0-9a-fA-F]{64}$/.test(keyMaterial)
      ? Buffer.from(keyMaterial, 'hex')
      : crypto.createHash('sha256').update(keyMaterial).digest();
  const decipher = crypto.createDecipheriv(
    'aes-256-gcm',
    key,
    Buffer.from(ivHex, 'hex'),
  );
  decipher.setAuthTag(Buffer.from(tagHex, 'hex'));
  return Buffer.concat([
    decipher.update(Buffer.from(dataHex, 'hex')),
    decipher.final(),
  ]).toString('utf8');
}

async function exchangeCodeWithLinkedIn({
  code,
  codeVerifier,
  redirectUri,
  clientId,
  clientSecret,
}) {
  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    code,
    redirect_uri: redirectUri,
    client_id: clientId,
    client_secret: clientSecret,
    code_verifier: codeVerifier,
  });

  const response = await fetch('https://www.linkedin.com/oauth/v2/accessToken', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });

  const text = await response.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch (_) {
    throw Object.assign(new Error('Invalid LinkedIn token response'), {
      status: 502,
      code: 'linkedin_token_invalid',
    });
  }

  if (!response.ok || !data.access_token) {
    const err = new Error(
      data.error_description || data.error || 'LinkedIn token exchange failed',
    );
    err.status = 400;
    err.code = data.error || 'linkedin_token_exchange_failed';
    throw err;
  }

  return data;
}

async function fetchLinkedInUserInfo(accessToken) {
  const response = await fetch('https://api.linkedin.com/v2/userinfo', {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const text = await response.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch (_) {
    throw Object.assign(new Error('Invalid LinkedIn userinfo response'), {
      status: 502,
      code: 'linkedin_userinfo_invalid',
    });
  }
  if (!response.ok) {
    const err = new Error(data.message || 'Failed to fetch LinkedIn profile');
    err.status = 400;
    err.code = 'linkedin_userinfo_failed';
    throw err;
  }
  return data;
}

/**
 * Optionally validate OIDC id_token claims (issuer, audience, nonce, exp).
 * Best-effort: if id_token is missing, continue with userinfo alone.
 */
function validateIdToken(idToken, { clientId, nonce }) {
  if (!idToken) return;
  const parts = idToken.split('.');
  if (parts.length < 2) {
    throw Object.assign(new Error('Malformed LinkedIn id_token'), {
      status: 400,
      code: 'invalid_id_token',
    });
  }
  const payload = JSON.parse(
    Buffer.from(parts[1].replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString(
      'utf8',
    ),
  );
  if (payload.iss && !String(payload.iss).includes('linkedin')) {
    throw Object.assign(new Error('Unexpected id_token issuer'), {
      status: 400,
      code: 'invalid_id_token_iss',
    });
  }
  if (payload.aud && payload.aud !== clientId) {
    throw Object.assign(new Error('id_token audience mismatch'), {
      status: 400,
      code: 'invalid_id_token_aud',
    });
  }
  if (payload.exp && Date.now() / 1000 > payload.exp) {
    throw Object.assign(new Error('LinkedIn id_token expired'), {
      status: 400,
      code: 'id_token_expired',
    });
  }
  if (nonce && payload.nonce && payload.nonce !== nonce) {
    throw Object.assign(new Error('OIDC nonce mismatch'), {
      status: 400,
      code: 'nonce_mismatch',
    });
  }
}

async function findUidByLinkedInSub(sub) {
  const db = admin.firestore();
  const byId = await db
    .collection('users')
    .where('linkedinId', '==', sub)
    .limit(1)
    .get();
  if (!byId.empty) return byId.docs[0].id;

  // Legacy synthetic Firebase Auth accounts from the old client-side flow.
  const syntheticEmail = `linkedin_${sub}@boardingpass.com`;
  try {
    const user = await admin.auth().getUserByEmail(syntheticEmail);
    return user.uid;
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
  }
  return null;
}

async function findUidByEmail(email) {
  const normalized = email.trim().toLowerCase();
  const db = admin.firestore();
  const snap = await db
    .collection('users')
    .where('email', '==', normalized)
    .limit(1)
    .get();
  if (!snap.empty) return snap.docs[0].id;

  try {
    const user = await admin.auth().getUserByEmail(normalized);
    return user.uid;
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
  }
  return null;
}

async function ensureFirebaseUser({ uid, email, name, picture }) {
  if (uid) {
    try {
      await admin.auth().getUser(uid);
      // Keep Auth profile fresh when possible.
      await admin.auth().updateUser(uid, {
        displayName: name || undefined,
        photoURL: picture || undefined,
        emailVerified: true,
      }).catch(() => {});
      return uid;
    } catch (e) {
      if (e.code !== 'auth/user-not-found') throw e;
    }
  }

  const created = await admin.auth().createUser({
    email,
    emailVerified: true,
    displayName: name || undefined,
    photoURL: picture || undefined,
  });
  return created.uid;
}

async function upsertUserProfile(uid, {
  sub,
  email,
  name,
  picture,
  profileUrl,
  isNew,
}) {
  const db = admin.firestore();
  const ref = db.collection('users').doc(uid);
  const now = admin.firestore.FieldValue.serverTimestamp();
  const snap = await ref.get();
  const existing = snap.data() || {};

  if (existing.isLoginRestricted === true) {
    const err = new Error('This account has been restricted by the safety team.');
    err.status = 403;
    err.code = 'account-restricted';
    throw err;
  }

  const authUser = await admin.auth().getUser(uid).catch(() => null);
  if (authUser?.disabled) {
    const err = new Error('This account has been restricted by the safety team.');
    err.status = 403;
    err.code = 'account-restricted';
    throw err;
  }

  const linkedInProvider = {
    provider: 'linkedin',
    providerUserId: sub,
    linkedAt: existing.authProviders?.linkedin?.linkedAt || now,
    lastLoginAt: now,
  };

  const authProviders = {
    ...(existing.authProviders || {}),
    linkedin: linkedInProvider,
  };

  const payload = {
    name: name || existing.name || 'User',
    email,
    linkedinId: sub,
    linkedinSynced: true,
    linkedinSyncedAt: now,
    lastSeen: now,
    lastLoginAt: now,
    updatedAt: now,
    authProviders,
    oauthProvider: 'linkedin',
    providerUserId: sub,
  };

  if (picture) payload.profileImageUrl = picture;
  if (profileUrl) payload.linkedinProfileUrl = profileUrl;

  if (!snap.exists) {
    payload.createdAt = now;
    payload.onboardingCompleted = false;
    payload.hasCompletedFeatureTour = false;
    payload.isDiscoverable = true;
    await ref.set(payload);
  } else {
    await ref.set(payload, { merge: true });
  }

  return {
    uid,
    name: payload.name,
    email,
    profileImageUrl: picture || existing.profileImageUrl || null,
    linkedinId: sub,
    onboardingCompleted: existing.onboardingCompleted === true,
    isNew: isNew || !snap.exists,
  };
}

async function storeLinkedInTokens(uid, tokenData, encryptionKey) {
  if (!encryptionKey) return;
  const access = encryptToken(tokenData.access_token, encryptionKey);
  const refresh = tokenData.refresh_token
    ? encryptToken(tokenData.refresh_token, encryptionKey)
    : null;
  if (!access) return;

  await admin.firestore().collection('oauth_tokens').doc(uid).set(
    {
      linkedin: {
        accessTokenEnc: access,
        refreshTokenEnc: refresh,
        expiresAt: tokenData.expires_in
          ? admin.firestore.Timestamp.fromMillis(
              Date.now() + Number(tokenData.expires_in) * 1000,
            )
          : null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    },
    { merge: true },
  );
}

async function revokeLinkedInToken(token) {
  if (!token) return false;
  try {
    const body = new URLSearchParams({ token });
    const response = await fetch('https://www.linkedin.com/oauth/v2/revoke', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    });
    return response.ok || response.status === 200;
  } catch (e) {
    logger.warn('LinkedIn revoke request failed', { error: String(e) });
    return false;
  }
}

/**
 * POST /exchangeLinkedInCode
 * Body: { data: { code, code_verifier, redirect_uri, nonce? } }
 */
exports.exchangeLinkedInCode = onRequest(
  {
    secrets: [LINKEDIN_CLIENT_SECRET],
    cors: true,
    timeoutSeconds: 60,
  },
  async (req, res) => {
    if (req.method === 'OPTIONS') {
      applyCors(res);
      res.status(204).send('');
      return;
    }

    applyCors(res);

    if (req.method !== 'POST') {
      res.status(405).json({ result: { ok: false, error: 'Method not allowed', code: 'method_not_allowed' } });
      return;
    }

    try {
      const body = parseBody(req);
      const code = (body.code ?? '').toString().trim();
      const codeVerifier = (body.code_verifier ?? body.codeVerifier ?? '').toString().trim();
      const redirectUri = (body.redirect_uri ?? body.redirectUri ?? '').toString().trim();
      const nonce = body.nonce ? String(body.nonce) : null;

      if (!code || !codeVerifier || !redirectUri) {
        res.status(200).json({
          result: {
            ok: false,
            error: 'Missing code, code_verifier, or redirect_uri.',
            code: 'invalid_request',
          },
        });
        return;
      }

      if (!isAllowedRedirectUri(redirectUri)) {
        logger.warn('Rejected LinkedIn redirect_uri', { redirectUri });
        res.status(200).json({
          result: {
            ok: false,
            error: 'Invalid redirect URI configuration.',
            code: 'invalid_redirect_uri',
          },
        });
        return;
      }

      const clientId = LINKEDIN_CLIENT_ID.value();
      const clientSecret = LINKEDIN_CLIENT_SECRET.value();

      const tokenData = await exchangeCodeWithLinkedIn({
        code,
        codeVerifier,
        redirectUri,
        clientId,
        clientSecret,
      });

      validateIdToken(tokenData.id_token, { clientId, nonce });

      const userInfo = await fetchLinkedInUserInfo(tokenData.access_token);
      const sub = (userInfo.sub || '').toString();
      const email = (userInfo.email || '').toString().trim().toLowerCase();
      const name =
        (userInfo.name ||
          `${userInfo.given_name || ''} ${userInfo.family_name || ''}`.trim() ||
          'User').toString();
      const picture = (userInfo.picture || '').toString();
      const profileUrl = (userInfo.profile || '').toString();

      if (!sub) {
        res.status(200).json({
          result: { ok: false, error: 'LinkedIn did not return a member id.', code: 'missing_sub' },
        });
        return;
      }
      if (!email) {
        res.status(200).json({
          result: {
            ok: false,
            error: 'No verified email returned from LinkedIn. Please grant email permission.',
            code: 'missing_email',
          },
        });
        return;
      }

      let uid = await findUidByLinkedInSub(sub);
      let isNew = false;
      if (!uid) {
        uid = await findUidByEmail(email);
      }
      if (!uid) {
        isNew = true;
      }

      uid = await ensureFirebaseUser({ uid, email, name, picture });

      const user = await upsertUserProfile(uid, {
        sub,
        email,
        name,
        picture,
        profileUrl,
        isNew,
      });

      try {
        // Optional: set LINKEDIN_TOKEN_ENCRYPTION_KEY in function env to persist
        // tokens for full-logout revoke support.
        await storeLinkedInTokens(
          uid,
          tokenData,
          process.env.LINKEDIN_TOKEN_ENCRYPTION_KEY || '',
        );
      } catch (storeErr) {
        logger.warn('Could not persist LinkedIn tokens', { error: String(storeErr) });
      }

      const customToken = await admin.auth().createCustomToken(uid, {
        provider: 'linkedin',
        linkedinId: sub,
      });

      res.status(200).json({
        result: {
          ok: true,
          customToken,
          user,
        },
      });
    } catch (e) {
      logger.error('exchangeLinkedInCode failed', { error: String(e), code: e.code });
      res.status(200).json({
        result: {
          ok: false,
          error: e.message || 'LinkedIn authentication failed',
          code: e.code || 'linkedin_auth_failed',
        },
      });
    }
  },
);

/**
 * POST /fullLogoutLinkedIn
 * Requires Authorization: Bearer <Firebase ID token>
 * Revokes stored LinkedIn tokens (if any) and deletes oauth_tokens doc.
 * Does NOT revoke LinkedIn's browser session.
 */
exports.fullLogoutLinkedIn = onRequest(
  {
    cors: true,
    timeoutSeconds: 30,
  },
  async (req, res) => {
    if (req.method === 'OPTIONS') {
      applyCors(res);
      res.status(204).send('');
      return;
    }

    applyCors(res);

    if (req.method !== 'POST') {
      res.status(405).json({ result: { ok: false, error: 'Method not allowed' } });
      return;
    }

    try {
      const authHeader = req.get('Authorization') || '';
      const match = authHeader.match(/^Bearer\s+(.+)$/i);
      if (!match) {
        res.status(401).json({ result: { ok: false, error: 'Unauthenticated', code: 'unauthenticated' } });
        return;
      }

      const decoded = await admin.auth().verifyIdToken(match[1]);
      const uid = decoded.uid;
      const encKey = process.env.LINKEDIN_TOKEN_ENCRYPTION_KEY || '';
      const tokenRef = admin.firestore().collection('oauth_tokens').doc(uid);
      const tokenSnap = await tokenRef.get();

      if (tokenSnap.exists) {
        const linkedin = tokenSnap.data()?.linkedin || {};
        if (encKey) {
          const access = decryptToken(linkedin.accessTokenEnc, encKey);
          const refresh = decryptToken(linkedin.refreshTokenEnc, encKey);
          await revokeLinkedInToken(refresh || access);
        }
        await tokenRef.delete().catch(() => {});
      }

      // Clear LinkedIn provider last-login marker only; keep account linkage.
      await admin.firestore().collection('users').doc(uid).set(
        {
          'authProviders.linkedin.revokedAt':
            admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      res.status(200).json({ result: { ok: true } });
    } catch (e) {
      logger.error('fullLogoutLinkedIn failed', { error: String(e) });
      res.status(200).json({
        result: {
          ok: false,
          error: e.message || 'Full logout failed',
          code: e.code || 'full_logout_failed',
        },
      });
    }
  },
);
