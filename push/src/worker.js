// Nordic Crypto app push server. See docs/push.md.
//   POST   /v1/publish         run now (the site's Deploy site workflow, after a publish;
//                              Authorization: Bearer <PUSH_PUBLISH_TOKEN>)
//   Cron (hourly fallback): the same run: poll the news API, queue new stories, send.
//   POST   /v1/devices         register or update a device
//   DELETE /v1/devices/:token  forget a device
//   GET    /v1/health          liveness
import { apnsConfigured, apnsJwt, apnsRequest, classifyApns } from "./apns.js";
import { classifyFcm, fcmConfigured, fcmRequest, fcmTokenRequest, parseServiceAccount } from "./fcm.js";
import { fetchFeed, newStories } from "./feed.js";
import { MAX_BODY, parseRegistration, transportFor, validToken, PLATFORMS } from "./devices.js";
import {
  deleteDevice, getState, pendingDeliveries, prune, recordStories, seenIds, setState, settle, upsertDevice,
} from "./db.js";

const SERVICE = "nordic-crypto-app-push";
const PARALLEL = 6; // Workers keep at most six connections open at once

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}

/** True when this server can actually deliver to `platform` (credentials are set). */
export function canDeliver(env, platform) {
  const t = transportFor(platform);
  return t === "apns" ? apnsConfigured(env) : t === "fcm" ? fcmConfigured(env) : false;
}

async function limited(env, key) {
  if (!env.REGISTER_LIMIT || typeof env.REGISTER_LIMIT.limit !== "function") return false;
  try {
    const { success } = await env.REGISTER_LIMIT.limit({ key });
    return !success;
  } catch {
    return false;
  }
}

async function readBody(request) {
  const len = Number(request.headers.get("content-length") || 0);
  if (len > MAX_BODY) return { error: "too_large" };
  const text = await request.text();
  if (text.length > MAX_BODY) return { error: "too_large" };
  try { return { value: JSON.parse(text) }; } catch { return { error: "bad_json" }; }
}

/** Constant-time check of the publish bearer token (compares SHA-256 digests). */
export async function publishAuthorized(request, env) {
  const want = (env.PUSH_PUBLISH_TOKEN || "").trim();
  const m = /^Bearer\s+(\S+)$/.exec(request.headers.get("authorization") || "");
  if (!want || !m) return false;
  const enc = new TextEncoder();
  const [a, b] = await Promise.all([m[1], want].map((s) => crypto.subtle.digest("SHA-256", enc.encode(s))));
  const x = new Uint8Array(a);
  const y = new Uint8Array(b);
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

export async function handleFetch(request, env, nowMs = Date.now(), fetchImpl = fetch) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, "") || "/";

  if (path === "/" || path === "/v1/health") {
    if (request.method !== "GET" && request.method !== "HEAD") return json({ ok: false, error: "method" }, 405);
    return json({
      ok: true,
      service: SERVICE,
      apns: apnsConfigured(env),
      fcm: fcmConfigured(env),
      publish: Boolean((env.PUSH_PUBLISH_TOKEN || "").trim()),
      platforms: Object.keys(PLATFORMS),
    });
  }

  if (path === "/v1/publish") {
    if (request.method !== "POST") return json({ ok: false, error: "method" }, 405);
    if (!(env.PUSH_PUBLISH_TOKEN || "").trim()) return json({ ok: false, error: "not_configured" }, 503);
    if (!(await publishAuthorized(request, env))) return json({ ok: false, error: "unauthorized" }, 401);
    const result = await runCron(env, nowMs, fetchImpl);
    return json({ ok: true, ...result });
  }

  if (path === "/v1/devices") {
    if (request.method !== "POST") return json({ ok: false, error: "method" }, 405);
    // The address is only a counter key at Cloudflare; this Worker never stores it.
    if (await limited(env, "ip:" + (request.headers.get("cf-connecting-ip") || "unknown"))) {
      return json({ ok: false, error: "rate_limited" }, 429);
    }
    const body = await readBody(request);
    if (body.error) return json({ ok: false, error: body.error }, body.error === "too_large" ? 413 : 400);
    const parsed = parseRegistration(body.value, nowMs);
    if (parsed.error) return json({ ok: false, error: parsed.error }, 400);
    const d = parsed.device;
    if (await limited(env, "token:" + d.token.slice(0, 64))) return json({ ok: false, error: "rate_limited" }, 429);
    if (!d.countries.length) {
      // Nothing wanted: keep nothing.
      await deleteDevice(env.DB, d.token);
      return json({ ok: true, stored: false, delivery: canDeliver(env, d.platform) });
    }
    await upsertDevice(env.DB, d);
    return json({ ok: true, stored: true, delivery: canDeliver(env, d.platform) });
  }

  const m = /^\/v1\/devices\/([^/]+)$/.exec(path);
  if (m) {
    if (request.method !== "DELETE") return json({ ok: false, error: "method" }, 405);
    let token;
    try { token = decodeURIComponent(m[1]); } catch { return json({ ok: false, error: "bad_token" }, 400); }
    if (!validToken("ios", token) && !validToken("android", token)) return json({ ok: false, error: "bad_token" }, 400);
    if (await limited(env, "ip:" + (request.headers.get("cf-connecting-ip") || "unknown"))) {
      return json({ ok: false, error: "rate_limited" }, 429);
    }
    const removed = (await deleteDevice(env.DB, token)) || (await deleteDevice(env.DB, token.toLowerCase()));
    return json({ ok: true, removed });
  }

  return json({ ok: false, error: "not_found" }, 404);
}

/** Step 1 of a cron run: read the feed and queue what is new. */
export async function pollFeed(env, nowMs, fetchImpl = fetch) {
  const db = env.DB;
  const etags = JSON.parse((await getState(db, "feed_etags")) || "{}");
  const feed = await fetchFeed(env, etags, fetchImpl);
  if (feed.status !== "ok") return { feed: feed.status, queued: 0 };
  const seen = await seenIds(db, feed.items.map((i) => i.id));
  const first = (await getState(db, "initialized")) === null;
  const { unseen, announce } = newStories(feed.items, seen, nowMs);
  // The very first run only learns what is already published.
  await recordStories(db, unseen, first ? [] : announce, nowMs);
  if (first) await setState(db, "initialized", new Date(nowMs).toISOString());
  if (feed.etag) {
    etags[feed.url] = feed.etag;
    await setState(db, "feed_etags", JSON.stringify(etags));
  }
  return { feed: "ok", new: unseen.length, queued: first ? 0 : announce.length };
}

async function providerTokens(env, nowSec, fetchImpl) {
  const db = env.DB;
  const out = { apns: null, fcm: null, sa: null };
  if (apnsConfigured(env)) {
    // Reuse for 40 minutes: Apple rejects tokens older than an hour and renewals more often than every 20 minutes.
    const cached = JSON.parse((await getState(db, "apns_jwt")) || "null");
    if (cached && cached.kid === env.APNS_KEY_ID && nowSec - cached.iat < 40 * 60) out.apns = cached.jwt;
    else {
      try {
        out.apns = await apnsJwt(env, nowSec);
        await setState(db, "apns_jwt", JSON.stringify({ jwt: out.apns, iat: nowSec, kid: env.APNS_KEY_ID }));
      } catch {
        out.apns = null;
      }
    }
  }
  const sa = parseServiceAccount(env.FCM_SERVICE_ACCOUNT_JSON);
  if (sa) {
    out.sa = sa;
    const cached = JSON.parse((await getState(db, "fcm_token")) || "null");
    if (cached && cached.client === sa.clientEmail && cached.exp - nowSec > 300) out.fcm = cached.token;
    else {
      try {
        const req = await fcmTokenRequest(sa, nowSec);
        const res = await fetchImpl(req.url, req.init);
        const body = await res.json();
        if (res.ok && body.access_token) {
          out.fcm = body.access_token;
          const exp = nowSec + Math.min(Number(body.expires_in) || 3600, 3600);
          await setState(db, "fcm_token", JSON.stringify({ token: out.fcm, exp, client: sa.clientEmail }));
        }
      } catch {
        out.fcm = null;
      }
    }
  }
  return out;
}

/** Step 2: send up to SENDS_PER_RUN queued notifications. */
export async function sendQueued(env, nowMs, fetchImpl = fetch) {
  const db = env.DB;
  const budget = Math.max(1, Math.min(Number(env.SENDS_PER_RUN) || 40, 900));
  const rows = await pendingDeliveries(db, nowMs, budget);
  const tally = { sent: 0, removed: 0, retry: 0, dropped: 0 };
  if (!rows.length) return tally;
  const nowSec = Math.floor(nowMs / 1000);
  const tokens = await providerTokens(env, nowSec, fetchImpl);
  const outcomes = [];
  let apnsAuthFailed = false;
  let fcmAuthFailed = false;

  async function one(row) {
    const item = JSON.parse(row.item);
    const language = (env.PUSH_LANGUAGE || "").trim() || row.language;
    const device = { token: row.token, platform: row.platform, environment: row.environment, language };
    const t = transportFor(row.platform);
    let req;
    let classify;
    if (t === "apns" && tokens.apns) {
      req = apnsRequest(device, item, tokens.apns, env, nowSec);
      classify = classifyApns;
    } else if (t === "fcm" && tokens.fcm) {
      req = fcmRequest(tokens.sa, tokens.fcm, device, item);
      classify = classifyFcm;
    } else {
      return { story_id: row.story_id, token: row.token, result: "skip" };
    }
    let result;
    try {
      const res = await fetchImpl(req.url, req.init);
      result = classify(res.status, res.status === 200 ? "" : await res.text());
    } catch {
      result = "retry";
    }
    if (result === "auth") {
      if (t === "apns") apnsAuthFailed = true; else fcmAuthFailed = true;
    }
    return { story_id: row.story_id, token: row.token, result };
  }

  for (let i = 0; i < rows.length; i += PARALLEL) {
    outcomes.push(...await Promise.all(rows.slice(i, i + PARALLEL).map(one)));
  }
  await settle(db, outcomes);
  // A rejected provider token is renewed on the next run.
  if (apnsAuthFailed) await db.prepare("DELETE FROM state WHERE key = 'apns_jwt'").run();
  if (fcmAuthFailed) await db.prepare("DELETE FROM state WHERE key = 'fcm_token'").run();
  for (const o of outcomes) {
    if (o.result === "ok") tally.sent++;
    else if (o.result === "remove") tally.removed++;
    else if (o.result === "retry" || o.result === "auth" || o.result === "skip") tally.retry++;
    else tally.dropped++;
  }
  return tally;
}

export async function runCron(env, nowMs = Date.now(), fetchImpl = fetch) {
  const poll = await pollFeed(env, nowMs, fetchImpl);
  const send = await sendQueued(env, nowMs, fetchImpl);
  await prune(env.DB, nowMs);
  return { ...poll, ...send };
}

export default {
  fetch(request, env) {
    return handleFetch(request, env);
  },
  scheduled(_event, env, ctx) {
    ctx.waitUntil(runCron(env));
  },
};
