# Bilingual Privacy Policy Qualification

## Identified Gap

The authenticated App Store Connect privacy page for Kras Pass 6801506973 links
to the repository main PRIVACY.md. The live page discloses linked User ID
collection for App Functionality. A fresh GitHub read of the main policy showed
English only. docs/apple-account-privacy.md requires equivalent Arabic/English
policy coverage before submission.

## Change

PRIVACY.md now contains Arabic and English sections. The Arabic text translates
the existing policy: local guest play and device saves, optional Apple account
authentication, Railway hosting, linked identifier purposes, transient email
processing, account deletion, session expiry, no advertising/cross-app tracking,
and no unnecessary gameplay permissions. The English substantive statements are
unchanged. Both language sections show the document revision date.

This is a documentation-only branch based on
d1a5a31f1d6af113e7c91dcdfa45acc68f2d41a9. It does not change the immutable source
of active natural balance campaign 37526080082 or restart its jobs.

## Verification Scope

The current local Xcode 27 physical-device QA build's Info.plist and privacy
manifest passed 20 metadata assertions: target Bundle ID, Xcode build metadata,
both orientations for both device families, absence of unused sensitive
permission descriptions, linked User ID for App Functionality, and no tracking.
Evidence: /tmp/kras-d1a5a31-privacy-check.mjs and
/tmp/kras-d1a5a31-privacy-qualification.md. The inspected app is development-signed
version 1.1.10/build 107, not a new Distribution archive.

Arabic translation meaning was manually reviewed. A 12-assertion Node check
confirmed that the English substantive paragraphs match the parent commit
exactly (excluding heading and revision date), and checked Arabic topic coverage,
the shared support link and dates. git diff --check passed. These checks do not
replace native account-flow acceptance or an independent legal review.

## Remaining Gates

The bilingual document is not published at the live main policy URL until its
change is approved and integrated. No App Store privacy answers or review status
were changed. Native Apple sign-in/deletion/revocation, backup retention and
production online-room privacy remain independent acceptance gates. This change
does not certify the entire app's legal compliance or upload a build to Apple.
