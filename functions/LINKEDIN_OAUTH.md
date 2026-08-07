# LinkedIn OAuth (Cloud Functions)

## Secrets

```bash
firebase functions:secrets:set LINKEDIN_CLIENT_SECRET
# Paste the LinkedIn app client secret from the Developer Portal.
```

Optional (enables encrypted token storage + revoke on Full Logout):

```bash
firebase functions:secrets:set LINKEDIN_TOKEN_ENCRYPTION_KEY
# Then bind it to both functions in Google Cloud / firebase.json env, or
# set as a plain env var for local emulation.
```

Optional client id param (defaults to the public app id):

```bash
# LINKEDIN_CLIENT_ID defaults to 86ltub3ua1c8o4 in code
```

## Deploy

```bash
firebase deploy --only functions:exchangeLinkedInCode,functions:fullLogoutLinkedIn,hosting,firestore:rules
```

After deploy, copy the HTTPS URLs for `exchangeLinkedInCode` and `fullLogoutLinkedIn`
into `lib/features/auth/data/oauth/linkedin_oauth_config.dart`
(`exchangeCodeUrl` / `fullLogoutUrl`, or the `*Alt` Cloud Run URLs).

## LinkedIn Developer Portal

Register these **Authorized redirect URLs**:

- `https://fir-p-57bdc.web.app/oauth/linkedin/callback`  (mobile bridge)
- `https://fir-p-57bdc.firebaseapp.com/oauth/linkedin/callback`
- Your Flutter web origin(s), e.g. `http://localhost:5000`, production SPA origin

Scopes: `openid profile email`

Do **not** enable forced re-auth / `prompt=login` for the default Continue with LinkedIn button.
