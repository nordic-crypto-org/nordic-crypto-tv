#!/usr/bin/env bash
# One-time setup of the app push server (push/, docs/push.md). Run by the
# owner on a trusted Mac; agents never run it. It only writes GitHub
# repository secrets: GitHub Actions (.github/workflows/push.yml) is the only
# path that deploys the Worker and uploads its secrets. Values go from files or
# a hidden prompt straight into `gh secret set` on stdin; nothing is printed and
# nothing is written to disk.
#
#   bash scripts/setup-push-secrets.sh \
#     --p8 ~/keys/AuthKey_ABCDE12345.p8 --key-id ABCDE12345 \
#     [--team-id YQBXSUUVJD] \
#     [--fcm-service-account ~/keys/nordic-crypto-push-firebase-adminsdk.json] \
#     [--google-services ~/keys/google-services.json] \
#     [--no-deploy]
#
# Secrets set on nordic-crypto-org/nordic-crypto-tv:
#   CLOUDFLARE_API_TOKEN (asked for, hidden, unless the variable is set) and
#   CLOUDFLARE_ACCOUNT_ID (looked up with the token unless the variable is set);
#   token permissions: Account > Workers Scripts > Edit, Account > D1 > Edit,
#   Account > Account Settings > Read
#   APNS_KEY_P8, APNS_KEY_ID, APNS_TEAM_ID
#   FCM_SERVICE_ACCOUNT_JSON              with --fcm-service-account
#   FIREBASE_APP_ID, FIREBASE_API_KEY,    with --google-services (the Android
#   FIREBASE_PROJECT_ID, FIREBASE_SENDER_ID   build's Firebase client settings)
# Then it starts the Push server workflow on main (unless --no-deploy), which
# deploys the code, the D1 migrations and the Worker secrets in one run.
#
# The APNs key must belong to the personal team YQBXSUUVJD. Never use the
# Bitcoin Unlimited team (8A87667ULD).
set -euo pipefail
REPO=nordic-crypto-org/nordic-crypto-tv
P8="" KEY_ID="" TEAM_ID=YQBXSUUVJD FCM_JSON="" GOOGLE_SERVICES="" DEPLOY=1

die() { echo "error: $*" >&2; exit 1; }
say() { printf '\n== %s\n' "$*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --p8) P8=$2; shift 2 ;;
    --key-id) KEY_ID=$2; shift 2 ;;
    --team-id) TEAM_ID=$2; shift 2 ;;
    --fcm-service-account) FCM_JSON=$2; shift 2 ;;
    --google-services) GOOGLE_SERVICES=$2; shift 2 ;;
    --no-deploy) DEPLOY=""; shift ;;
    -h|--help) sed -n '2,29p' "$0"; exit 0 ;;
    *) die "unknown option $1 (see --help)" ;;
  esac
done

[ -n "$P8" ] && [ -n "$KEY_ID" ] || die "--p8 and --key-id are required (see --help)"
[ "$TEAM_ID" != "8A87667ULD" ] || die "8A87667ULD is the Bitcoin Unlimited team. Use the personal team YQBXSUUVJD."
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || die "--team-id must be 10 letters/digits"
[[ "$KEY_ID" =~ ^[A-Z0-9]{10}$ ]] || die "--key-id must be the 10-character APNs key id"
[ -r "$P8" ] || die "cannot read $P8"
grep -q -- "-----BEGIN PRIVATE KEY-----" "$P8" || die "$P8 is not an APNs .p8 key"
if [ -n "$FCM_JSON" ]; then
  [ -r "$FCM_JSON" ] || die "cannot read $FCM_JSON"
  node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));if(s.type!=="service_account"||!s.private_key||!s.client_email||!s.project_id)process.exit(1)' "$FCM_JSON" \
    || die "$FCM_JSON is not a Google service account key"
fi
if [ -n "$GOOGLE_SERVICES" ]; then
  [ -r "$GOOGLE_SERVICES" ] || die "cannot read $GOOGLE_SERVICES"
fi
command -v gh >/dev/null || die "gh is not installed"
command -v node >/dev/null || die "node is not installed"
command -v curl >/dev/null || die "curl is not installed"
login=$(gh api user -q .login) || die "gh is not logged in"
[ "$login" = jQrgen ] || die "gh is logged in as $login, expected jQrgen"

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  read -r -s -p "Cloudflare API token (input hidden): " CLOUDFLARE_API_TOKEN; echo
fi
[ -n "$CLOUDFLARE_API_TOKEN" ] || die "no Cloudflare API token"
# The token goes to curl on stdin, not on its command line.
cf() { printf 'Authorization: Bearer %s\n' "$CLOUDFLARE_API_TOKEN" | curl -fsS -H @- "https://api.cloudflare.com/client/v4$1"; }
cf /user/tokens/verify | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const d=JSON.parse(s);process.exit(d.success&&d.result.status==="active"?0:1)})' \
  || die "the Cloudflare token is not active"
if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
  CLOUDFLARE_ACCOUNT_ID=$(cf /accounts | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=JSON.parse(s).result;process.stdout.write(r.length===1?r[0].id:"")})')
  [ -n "$CLOUDFLARE_ACCOUNT_ID" ] || die "the token sees no account or several; export CLOUDFLARE_ACCOUNT_ID"
fi

set_secret() { # set_secret NAME  (value on stdin)
  gh secret set "$1" --repo "$REPO" >/dev/null
  echo "GitHub secret $1 set"
}

say "GitHub secrets on $REPO"
printf '%s' "$CLOUDFLARE_API_TOKEN" | set_secret CLOUDFLARE_API_TOKEN
printf '%s' "$CLOUDFLARE_ACCOUNT_ID" | set_secret CLOUDFLARE_ACCOUNT_ID
set_secret APNS_KEY_P8 < "$P8"
printf '%s' "$KEY_ID" | set_secret APNS_KEY_ID
printf '%s' "$TEAM_ID" | set_secret APNS_TEAM_ID
if [ -n "$FCM_JSON" ]; then
  node -e 'process.stdout.write(JSON.stringify(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))))' "$FCM_JSON" \
    | set_secret FCM_SERVICE_ACCOUNT_JSON
fi
if [ -n "$GOOGLE_SERVICES" ]; then
  # The Android app's Firebase client settings (not the service account). Package no.cryptonordic.app.
  for field in app_id api_key project_id sender_id; do
    node -e '
      const g = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
      const c = (g.client || []).find((x) => x.client_info?.android_client_info?.package_name === "no.cryptonordic.app");
      if (!c) { console.error("no client for no.cryptonordic.app in google-services.json"); process.exit(1); }
      const v = { app_id: c.client_info.mobilesdk_app_id, api_key: (c.api_key || [])[0]?.current_key,
                  project_id: g.project_info.project_id, sender_id: g.project_info.project_number }[process.argv[2]];
      if (!v) process.exit(1);
      process.stdout.write(String(v));' "$GOOGLE_SERVICES" "$field" \
      | set_secret "FIREBASE_$(echo "$field" | tr a-z A-Z)"
  done
fi

if [ -n "$DEPLOY" ]; then
  say "deploy"
  if gh workflow view push.yml --repo "$REPO" >/dev/null 2>&1 && gh workflow run push.yml --repo "$REPO" --ref main; then
    echo "Started the Push server workflow on main: https://github.com/$REPO/actions/workflows/push.yml"
    echo "It deploys the Worker, the D1 migrations and the secrets, then checks"
    echo "https://nordic-crypto-app-push.nordiccrypto.workers.dev/v1/health (\"apns\":true,\"fcm\":true)."
  else
    echo "The Push server workflow is not on main yet; the first push to main after the merge deploys."
  fi
fi
say "done"
echo "To rotate a key later, run this script again; every push to main and every manual run redeploys."
