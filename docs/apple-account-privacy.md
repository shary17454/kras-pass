# Account privacy disclosure update

Prepared for optional Sign in with Apple. This does not update the published
App Store privacy answers or public policy URL.

The server stores Apple user identifier, account creation time, access binding
and hashed session credentials. Verified email is processed initially to match
a private account entitlement; ordinary emails and identity tokens are not
retained. No advertising or cross-app tracking is introduced.

Purpose: authentication, account management and game access. Hosting: Railway
with persistent SQLite, using HTTPS. Device sessions use profile-scoped Keychain.
Local gameplay progress is not uploaded by this feature.

Profile > Account > Delete Account revokes Apple authorization and removes the
server account and sessions. Local progress remains, as stated in confirmation.
Logging out removes only the current session.

Before submission: publish equivalent Arabic/English policy text and disclose
linked User ID collection for App Functionality in App Store Connect. Review
retention, backup policies and the whole release binary's data practices.
