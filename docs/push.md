# Push notifications for new stories

Status: proposed (pull request). Date: 11 October 2026.

## Context

Until now, every app checked for new stories itself. iPhone and iPad used a background refresh that
iOS runs when it likes, the Mac checked every 15 minutes while the app was open, Android used
WorkManager every 15 minutes, and Vision Pro had no notifications. Notifications came late or not at
all, and every device downloaded the whole news list (about 300 KB) to find one new headline.

The news comes from the static API at `https://nordiccrypto.no/api/v1/`. It is built by the website
repository ([jQrgen/nordic-crypto](https://github.com/jQrgen/nordic-crypto)) and served by GitHub
Pages. That repository already runs Cloudflare Workers (browser Web Push in `workers/push`, tips,
mint), so a Worker is the natural home for a push server too.

## Decision

A Cloudflare Worker in [`push/`](../push/) with a D1 database, triggered by the website's publish
with an hourly Cron Trigger as the fallback.

**Trigger (since October 2026).** After each successful publish, the site's *Deploy site* workflow
(`nordic-crypto-org/nordic-crypto`, `.github/workflows/deploy.yml`) waits until the live
`latest.json` is the one it just built and calls `POST /v1/publish` with
`Authorization: Bearer <PUSH_PUBLISH_TOKEN>` (repository secret `PUSH_PUBLISH_TOKEN` here, uploaded
to the Worker by `deploy.sh`; the same value is `APP_PUSH_PUBLISH_TOKEN` in the site repository).
That runs the same check as the cron right away. The cron runs hourly (`0 * * * *`) and catches
anything a failed call missed. Each run is one publish: a device gets **at most one notification
per run**, the newest new story in one of its countries; other new stories are only remembered.
`PUSH_LANGUAGE` (`wrangler.toml`, `en`) sets the language of every notification; empty means the
device's language. The payload carries `story` (opens the story in the app) and `url` (the story's
page, `html_url`).

```
 publish/hour  GET /api/v1/news/latest.json  (If-None-Match; 304 when nothing changed)
 Cron ───────► new ids? ── no ──► send what is still queued
                  │ yes
                  ▼
        stories (seen ids) + deliveries (story × device that chose its country)
                  │
                  ▼  up to SENDS_PER_RUN per run, 6 at a time
        APNs (iPhone, iPad, Mac, Vision Pro)      FCM HTTP v1 (Android)
```

1. **Feed.** The cron polls `/api/v1/news/latest.json`, a new endpoint added in
   [jQrgen/nordic-crypto#108](https://github.com/jQrgen/nordic-crypto/pull/108): the 25 newest
   stories with only id, published, country, source and the headlines (about 25 KB, bounded). It
   sends `If-None-Match`; GitHub Pages answers `304` while nothing changed. While `latest.json` does
   not exist yet (404), the Worker reads `news.json` instead, so it works before that pull request
   is merged. Why not only ETags on `news.json`: it is 300 KB and growing, and its ETag changes on
   every gh-pages deploy (the hourly markets refresh included), so the full list would still be
   downloaded at least once an hour.
2. **What is new.** Story ids not in the `stories` table. The first run only learns what is
   already published. A story published more than 48 hours ago that appears late (backfill) is
   remembered but not announced. More than 10 new stories at once looks like a reset and is
   remembered without announcing.
3. **Who gets it.** One notification per run (the newest new story) to every device whose countries include the
   story's country (`NO`, `SE`, `DK`, `FI`, `IS`; the server also accepts `NORDIC` and `EU`). The
   text is the same as the apps' own notifications: title "Source · Country" (country name in the
   device's language, from the app's string catalogue via `push/scripts/gen-copy.mjs`), body the
   headline in the device's language: the source headline when it is already in that language,
   else `title_i18n[lang]`, else `title_en`, else `title`. Tapping it opens the story
   (`story` in the APNs payload, a `story` extra on Android).
4. **Queue.** New stories become rows in `deliveries` (story × device). Each run sends at most
   `SENDS_PER_RUN` (40; the Workers Free plan allows 50 subrequests per run, raise it to about 900
   on Workers Paid). Rows older than 6 hours or tried 3 times are dropped: old news is not worth a
   buzz. A larger audience on the Free plan is spread over the next runs (40 per run);
   Cloudflare Queues would be the next step if that gets too slow.
5. **APNs.** Token-based auth: an ES256 JWT signed with an APNs `.p8` key of the personal team
   **YQBXSUUVJD** (never the Bitcoin Unlimited team 8A87667ULD), topic `no.cryptonordic.tv`, push
   type `alert`, `apns-collapse-id` = story id, expiry 6 hours. The JWT is cached in D1 for 40
   minutes (Apple wants it renewed after 20 to 60 minutes and rejects more frequent renewals). Each
   device says whether its token is `production` (TestFlight, App Store) or `sandbox` (Xcode debug
   builds); the Worker uses `api.push.apple.com` or `api.sandbox.push.apple.com` accordingly.
   APNs needs HTTP/2: `fetch()` from the deployed Worker negotiates it at the Cloudflare edge, but
   `wrangler dev` on a laptop does not, so APNs delivery can only be tried on the deployed Worker.
6. **FCM.** HTTP v1 API (`projects/<id>/messages:send`) with a service account of a personal
   Firebase project: an RS256 JWT is exchanged for a one-hour OAuth token, cached in D1. Messages
   are notification messages on channel `new-stories` with the app's notification icon, TTL 6
   hours.
7. **Dead tokens.** APNs `410 Unregistered`, `BadDeviceToken`, `DeviceTokenNotForTopic` and FCM
   `UNREGISTERED`/`404`/invalid registration token delete the device. Rate limits and server errors
   are retried on the next runs; a rejected provider token is renewed on the next run.
8. **Fallback.** The apps keep the on-device check. It stays quiet while the push server has
   accepted the device and can deliver to it (`"delivery": true` in the registration reply) and
   takes over when push is not available: no server, no credentials on the server, no token,
   no network, or an Android build without Firebase settings.
9. **Not on TV.** tvOS has no alert notifications and Android TV has no notification settings in
   the app; both keep the information screen as it is and never register.

### HTTP API

Base URL: `https://nordic-crypto-app-push.nordiccrypto.workers.dev` (Worker `nordic-crypto-app-push`
on the `nordiccrypto` workers.dev subdomain; set in `APIConfig.pushServer` and in the Android
`PUSH_SERVER_URL` build setting).

| Method | Path | Body / answer |
|---|---|---|
| GET | `/v1/health` | `{"ok":true,"service":"nordic-crypto-app-push","apns":bool,"fcm":bool,"platforms":[…]}` |
| POST | `/v1/devices` | `{"token","platform":"ios\|ipados\|macos\|visionos\|android","countries":["NO",…],"language":"nb","environment":"production\|sandbox"}` → `{"ok":true,"stored":true,"delivery":bool}`. Same token again updates. Empty `countries` deletes. |
| DELETE | `/v1/devices/:token` | `{"ok":true,"removed":bool}` |

Validation: APNs tokens are hex (64 to 200 characters), FCM tokens URL-safe text; unknown platform,
country or environment is a 400; bodies over 4 KB are a 413; unknown languages become `en`. Rate
limit: the Workers Rate Limiting binding allows 20 registrations per minute per client address and
per token at each Cloudflare location (the counter key is never stored by the Worker). There is no
account and no authentication: the push token is the key, and only the device knows it.

### What is stored

| Table | Columns | Kept for |
|---|---|---|
| `devices` | push token, platform, APNs environment, language, countries, last update time | until notifications are turned off, the token is reported dead, or 180 days without the app checking in (the apps re-register at most once a day) |
| `stories` | story id, when it was seen, the public story fields while it may still be sent | 30 days (fields: 6 hours) |
| `deliveries` | story id, push token, queued time, attempts | until sent, at most 6 hours |
| `state` | feed ETags, first-run marker, cached APNs JWT and FCM access token | replaced as they expire |

No IP address, name, email, device name, user agent or location. Workers observability (request
logs) is off and the code logs nothing. Cloudflare, Apple and Google see what any request or push
shows them (Cloudflare the client IP of a registration; Apple and Google the token and the message).

## Alternatives considered

- **Keep checking on the device.** No server and no data, but late and unreliable on iOS, and it
  never worked on Vision Pro. Kept as the fallback.
- **Reuse the website's `workers/push`.** It is Web Push (VAPID) triggered by `publish.sh`, with
  KV storage and one batch notification per publish. Native push needs APNs and FCM credentials,
  per-story messages and per-device languages; mixing both in one Worker would couple the app to
  the website's publish pipeline. The patterns (no personal data, health route, deploy script,
  `node --test`) are reused.
- **Trigger from the website's publish.** Lower latency, but the app server would then depend on
  the website repository's secrets and pipeline. Polling a public endpoint keeps the two
  independent; latency is at most the 5-minute cron plus GitHub Pages' 10-minute cache.
- **KV instead of D1.** Selecting devices by country and keeping a queue are queries; KV would mean
  listing every key on every story.
- **Firebase for iOS too.** One provider, but it adds the Firebase SDK and Google to the Apple apps.
  APNs directly keeps Google out of the Apple apps.

## Consequences

- A push token and the country and language choice now leave the device when notifications are on.
  README, the in-app notification settings text (21 languages), `support/appstore/privacy-policy.md`,
  `PrivacyInfo.xcprivacy` (Device ID, app functionality, not linked, no tracking) and the Play
  listing say so.
- The Apple app has the `aps-environment` entitlement on iOS, iPadOS and visionOS
  (`NordicCrypto-iOS.entitlements`) and `com.apple.developer.aps-environment` on macOS. The App ID
  needs the Push Notifications capability and the provisioning profiles must be regenerated
  (below).
- Android depends on `com.google.firebase:firebase-messaging`. Firebase is initialised in code from
  build settings, so no `google-services.json` and no Google Services Gradle plugin are needed. With
  notifications off, Firebase never creates a token (`firebase_messaging_auto_init_enabled` is
  false); there is no Firebase Analytics.
- New secrets live only in GitHub repository secrets (set once by the owner's script) and, copied
  there by the deploy job, in the Worker.

## Deployment

GitHub Actions is the only deploy path; nothing is deployed from a laptop.

- **[`.github/workflows/push.yml`](../.github/workflows/push.yml)**, job `test`: unit tests, the
  country-name check and `wrangler deploy --dry-run`, on every pull request that touches `push/`,
  the string catalogue or the workflow, and before every deploy.
- Job `deploy`: on **every push to `main`** and every manual run (Actions → Push server → Run
  workflow), after the tests, [`push/deploy.sh`](../push/deploy.sh) does everything in one run:
  1. finds or creates the D1 database `nordic-crypto-app-push` and writes its id into a temporary
     `wrangler.deploy.toml` (the committed `wrangler.toml` keeps a placeholder);
  2. applies the D1 migrations;
  3. deploys the code;
  4. uploads the Worker secrets `APNS_KEY_P8`, `APNS_KEY_ID`, `APNS_TEAM_ID` and
     `FCM_SERVICE_ACCOUNT_JSON` from the repository secrets of the same names with
     `wrangler secret bulk`: the JSON is built in memory by Node, checked (a `.p8` key, a service
     account key, never the Bitcoin Unlimited team id), and handed to wrangler on stdin, never
     written to a file or printed. A secret that is not set is skipped with a notice and the
     Worker keeps its current value;
  5. checks `/v1/health`, which reports `"apns"` and `"fcm"` as true once the credentials are in.

  Without `CLOUDFLARE_API_TOKEN` the job skips with a notice. Repository secrets used:
  `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `APNS_KEY_P8`, `APNS_KEY_ID`, `APNS_TEAM_ID`,
  `FCM_SERVICE_ACCOUNT_JSON`.
- **Android builds** read `FIREBASE_APP_ID`, `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID` and
  `FIREBASE_SENDER_ID` from the environment ([android.yml](../.github/workflows/android.yml) passes
  the repository secrets of the same names) or from `~/.gradle/gradle.properties`
  (`firebaseAppId`, `firebaseApiKey`, `firebaseProjectId`, `firebaseSenderId`). These are the
  client settings from `google-services.json`, not the service account. They end up in the APK, as
  with any Firebase app; restrict the API key (below). The file itself is not committed.

## One-time setup (owner)

Agents never set these secrets. Everything below uses personal accounts. Do steps 1 to 4 **before
merging**: once the push entitlement is in `main`, TestFlight builds for iPhone, iPad, Vision Pro
and Mac need provisioning profiles that include Push Notifications.

1. **Apple** (developer.apple.com, team **YQBXSUUVJD**):
   1. Certificates, Identifiers & Profiles → Identifiers → `no.cryptonordic.tv` → enable
      **Push Notifications** → Save. This invalidates the current App Store profiles.
   2. Keys → **+** → name "Nordic Crypto push", tick **Apple Push Notifications service (APNs)**,
      environment **Sandbox & Production** → download `AuthKey_<KEYID>.p8` (only once) and note the
      Key ID.
   3. Regenerate the App Store profiles so they carry the push entitlement: re-run
      `bash scripts/setup-signing-github.sh --key-id … --issuer-id … --p8 …` (it runs
      `fastlane match appstore` for ios, tvos and macos and recreates invalid profiles). If a
      profile is still the old one, run match for that platform with `--force`. Xcode's automatic
      signing picks up the capability by itself for local builds.
2. **Firebase** (console.firebase.google.com, personal Google account):
   1. Create a project (e.g. `nordic-crypto-push`), no Google Analytics.
   2. Add an Android app with package `no.cryptonordic.app`; download `google-services.json`; do not
      commit it.
   3. Project settings → Service accounts → **Generate new private key** (the default
      `firebase-adminsdk` account can send FCM; the "Firebase Cloud Messaging API (V1)" must be
      enabled, which new projects have). Keep the JSON outside the repository.
   4. Google Cloud console → APIs & Services → Credentials → the Android API key → restrict it to
      the Android app `no.cryptonordic.app` (with the Play and upload signing SHA-1s) and to the
      Firebase Installations and FCM registration APIs.
3. **Cloudflare** (the account with the `nordiccrypto.workers.dev` subdomain): My Profile → API
   Tokens → Create token with **Account › Workers Scripts › Edit**, **Account › D1 › Edit** and
   **Account › Account Settings › Read**.
4. **Run once** from a checkout of this repository, with `gh` logged in as jQrgen and Node:

   ```sh
   bash scripts/setup-push-secrets.sh \
     --p8 ~/keys/AuthKey_<KEYID>.p8 --key-id <KEYID> --team-id YQBXSUUVJD \
     --fcm-service-account ~/keys/<firebase-adminsdk>.json \
     --google-services ~/keys/google-services.json
   ```

   It asks for the Cloudflare token (hidden), checks it and looks up the account id with the
   Cloudflare API, and only writes GitHub repository secrets (`gh secret set`, values on stdin,
   nothing printed, nothing written to disk): `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`,
   `APNS_KEY_P8`, `APNS_KEY_ID`, `APNS_TEAM_ID`, `FCM_SERVICE_ACCOUNT_JSON`, `FIREBASE_APP_ID`,
   `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_SENDER_ID`. It makes no wrangler calls.
   Then it starts the Push server workflow on `main` (skip with `--no-deploy`; before the merge
   the first push to `main` deploys). From then on everything deploys from Actions; to rotate a
   key, run the script again. Afterwards
   `curl https://nordic-crypto-app-push.nordiccrypto.workers.dev/v1/health` shows
   `"apns":true,"fcm":true`.
5. **Store forms and policy:**
   - App Store Connect → App Privacy: add **Identifiers → Device ID**, used for App Functionality,
     not linked to the user, not used for tracking (matches `PrivacyInfo.xcprivacy`).
   - Play Console → Data safety: **Device or other IDs** collected (not shared; Google delivers as a
     service provider), purpose App functionality, optional (only with notifications on), encrypted
     in transit, deletable (turning notifications off deletes it).
   - Both stores link `https://nordiccrypto.no/privacy/` (`jqrgen.github.io/nordic-crypto/privacy/`)
     as the privacy policy. That page is about the website and does not describe the apps yet; add
     a short "Apps: push notifications" section there (the text of
     `support/appstore/privacy-policy.md`, Notifications) before push reaches testers.

## Testing

- `cd push && npm ci && npm test`: 28 tests with Node's test runner and a small D1 stand-in on
  `node:sqlite`, no network: feed parsing, diffing and conditional requests, headline and language
  choice, the APNs payload and request (host per environment, headers), APNs JWT signing and
  verification with a throwaway P-256 key, the FCM OAuth JWT (RS256, throwaway key) and HTTP v1
  request shape, response handling (dead tokens removed, retries, provider-token renewal), the
  queue budget, pruning, and the device API (validation, update, delete, rate limit, nothing but
  the token and preferences stored).
- `npm run dry-run`: `wrangler deploy --dry-run`.
- After deploying: turn notifications on in a TestFlight build, check that the device appears
  (`npx wrangler d1 execute nordic-crypto-app-push --remote --command "select platform, language, countries from devices"`)
  and wait for the next story, or insert a test delivery by hand.

## Follow-ups

- Android: firebase-messaging 25.1 deprecates `getToken()`/`deleteToken()` in favour of
  `register()`/`onRegistered()`. The app already handles `onRegistered`; move token retrieval over
  once the new flow is documented.
- If the audience outgrows 40 pushes per 5 minutes on the Free plan: Workers Paid (raise
  `SENDS_PER_RUN`) or Cloudflare Queues.
- Optional: a custom hostname such as `push.nordiccrypto.no` (DNS is on Cloudflare) instead of
  workers.dev; change `APIConfig.pushServer` and `PUSH_SERVER_URL` with it.
