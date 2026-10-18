#!/usr/bin/env bash
# Deploys the app push Worker in one go: finds or creates the D1 database,
# applies the migrations, deploys the code, uploads the Worker secrets and
# checks /v1/health. Runs in GitHub Actions (.github/workflows/push.yml), the
# only deploy path; it also works by hand with the same environment.
#
# Needs CLOUDFLARE_API_TOKEN (and CLOUDFLARE_ACCOUNT_ID when the token sees more
# than one account). Token permissions: Account > Workers Scripts > Edit,
# Account > D1 > Edit, Account > Account Settings > Read.
#
# Worker secrets, read from the environment and uploaded with
# `wrangler secret bulk` on stdin (never written to a file, never printed);
# unset ones are skipped with a notice and keep their current value:
#   APNS_KEY_P8 (contents of the .p8), APNS_KEY_ID, APNS_TEAM_ID,
#   FCM_SERVICE_ACCOUNT_JSON (contents of the service account key),
#   PUSH_PUBLISH_TOKEN (bearer token for POST /v1/publish, shared with the site repo)
set -euo pipefail
cd "$(dirname "$0")"
DB_NAME=nordic-crypto-app-push
[ -n "${CLOUDFLARE_API_TOKEN:-}" ] || { echo "CLOUDFLARE_API_TOKEN is not set"; exit 1; }
[ "${APNS_TEAM_ID:-}" != "8A87667ULD" ] || { echo "APNS_TEAM_ID is the Bitcoin Unlimited team; use the personal team YQBXSUUVJD"; exit 1; }
[ -d node_modules/wrangler ] || npm ci --no-audit --no-fund
wr() { npx --no-install wrangler "$@"; }
# A GitHub Actions notice in CI, a plain line elsewhere.
note() { if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::notice title=Push server::$*"; else echo "note: $*"; fi; }

id=$(wr d1 list --json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=JSON.parse(s).find(d=>d.name===process.argv[1]);process.stdout.write(r?r.uuid:"")})' "$DB_NAME")
if [ -z "$id" ]; then
  echo "creating D1 database $DB_NAME"
  wr d1 create "$DB_NAME" >/dev/null
  id=$(wr d1 list --json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=JSON.parse(s).find(d=>d.name===process.argv[1]);process.stdout.write(r?r.uuid:"")})' "$DB_NAME")
fi
[ -n "$id" ] || { echo "could not find or create the D1 database $DB_NAME"; exit 1; }
echo "D1 $DB_NAME: $id"

# The committed wrangler.toml keeps a placeholder id; deploy from a copy with the real one.
sed "s/^database_id = \"00000000-0000-0000-0000-000000000000\"/database_id = \"$id\"/" wrangler.toml > wrangler.deploy.toml
grep -q "database_id = \"$id\"" wrangler.deploy.toml || { echo "could not set database_id"; exit 1; }

node scripts/gen-copy.mjs --check
wr d1 migrations apply "$DB_NAME" --remote --config wrangler.deploy.toml
out=$(wr deploy --config wrangler.deploy.toml 2>&1) || { echo "$out"; exit 1; }
echo "$out" | grep -viE 'token|secret|bearer' | tail -15
url=$(echo "$out" | grep -oE 'https://[A-Za-z0-9.-]+\.workers\.dev' | head -1 || true)
[ -n "$url" ] || { echo "no workers.dev URL in the deploy output"; exit 1; }

# Worker secrets from the environment. Only names are printed.
names=$(node -e '
  const names = ["APNS_KEY_P8", "APNS_KEY_ID", "APNS_TEAM_ID", "FCM_SERVICE_ACCOUNT_JSON", "PUSH_PUBLISH_TOKEN"];
  process.stdout.write(names.filter((n) => (process.env[n] || "").trim()).join(" "));')
for n in APNS_KEY_P8 APNS_KEY_ID APNS_TEAM_ID FCM_SERVICE_ACCOUNT_JSON PUSH_PUBLISH_TOKEN; do
  case " $names " in *" $n "*) ;; *) note "secret $n is not set in this environment; the Worker keeps its current value (if any)" ;; esac
done
if [ -n "$names" ]; then
  # Validated first, kept in memory only, then handed to wrangler on stdin.
  payload=$(node -e '
    const out = {};
    for (const n of process.argv.slice(1)) out[n] = process.env[n].trim();
    if (out.FCM_SERVICE_ACCOUNT_JSON) {
      let sa = {};
      try { sa = JSON.parse(out.FCM_SERVICE_ACCOUNT_JSON); } catch { sa = {}; } // no parser message: it would quote the key
      if (!sa.client_email || !sa.private_key || !sa.project_id) { console.error("FCM_SERVICE_ACCOUNT_JSON is not a service account key"); process.exit(1); }
      out.FCM_SERVICE_ACCOUNT_JSON = JSON.stringify(sa);
    }
    if (out.APNS_KEY_P8 && !out.APNS_KEY_P8.includes("BEGIN PRIVATE KEY")) { console.error("APNS_KEY_P8 is not a .p8 key"); process.exit(1); }
    process.stdout.write(JSON.stringify(out));' $names)
  printf '%s' "$payload" | wr secret bulk --config wrangler.deploy.toml >/dev/null
  unset payload
  echo "Worker secrets uploaded: $names"
fi
echo "worker URL: $url"
for _ in $(seq 1 20); do
  if body=$(curl -fsS --max-time 10 "$url/v1/health"); then
    echo "health: $body"
    exit 0
  fi
  sleep 3
done
echo "health check failed at $url/v1/health"
exit 1
