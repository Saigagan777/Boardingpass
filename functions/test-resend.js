/**
 * Sends the Resend "Hello World" test email.
 *
 * Run from the functions/ directory:
 *
 *   npm run test:email
 *
 * (or: node --env-file=.env test-resend.js)
 *
 * The recipient and content can be edited below. The RESEND_API_KEY is read
 * from functions/.env automatically.
 */
const { sendEmail } = require('./email-service');

async function main() {
  try {
    const data = await sendEmail({
      to: 'kotagagan87@gmail.com',
      subject: 'Hello World',
      html: '<p>Congrats on sending your <strong>first email</strong>!</p>',
    });
    console.log('Email sent! Resend id:', data.id);
  } catch (e) {
    console.error('Failed to send email:', e.message);
    process.exitCode = 1;
  }
}

main();
