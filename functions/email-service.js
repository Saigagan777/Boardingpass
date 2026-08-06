/**
 * Reusable Resend email service.
 *
 * The API key is read from the environment (RESEND_API_KEY) — never hardcode
 * it in source code. For local runs the key lives in functions/.env
 * (gitignored); for Firebase Cloud Functions, set it as a secret:
 *
 *   firebase functions:secrets:set RESEND_API_KEY
 *
 * and reference it with defineSecret (see the README / Firebase docs).
 */
const { Resend } = require('resend');

const API_KEY = process.env.RESEND_API_KEY;
const DEFAULT_FROM = 'onboarding@nexmeet.world'; // Verified domain sender

if (!API_KEY) {
  // Not fatal at import time — functions may be deployed without the key.
  console.warn(
    '[email-service] RESEND_API_KEY is not set. Emails will fail until it is configured.',
  );
}

const resend = API_KEY ? new Resend(API_KEY) : null;

/**
 * Sends an email via Resend.
 *
 * @param {object} params
 * @param {string} params.to      Recipient email address(es) or comma-separated string.
 * @param {string} params.subject Email subject.
 * @param {string} params.html    HTML body.
 * @param {string} [params.from]  Sender address (defaults to the sandbox sender).
 * @returns {Promise<{id: string}>}
 */
async function sendEmail({ to, subject, html, from = DEFAULT_FROM }) {
  if (!resend) {
    throw new Error(
      'Resend is not configured: set the RESEND_API_KEY environment variable.',
    );
  }

  const { data, error } = await resend.emails.send({
    from,
    to,
    subject,
    html,
  });

  if (error) {
    if (error.name === 'validation_error') {
      throw new Error(`Resend Validation Error: ${error.message}`);
    }
    throw new Error(`Resend failed: ${error.message}`);
  }

  return data;
}

module.exports = { sendEmail };
