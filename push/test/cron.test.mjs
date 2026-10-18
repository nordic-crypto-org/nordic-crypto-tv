import { test } from "node:test";
import assert from "node:assert/strict";
import { handleFetch, runCron } from "../src/worker.js";
import { FakeD1 } from "./d1.mjs";
import { testKeys } from "./keys.mjs";

const keys = testKeys();
const NOW = Date.parse("2026-10-11T12:00:00Z");
const MIN = 60e3;
const FEED = "https://nordiccrypto.no/api/v1/news/latest.json";
const IPHONE = "11".repeat(32);
const MAC_DEV = "22".repeat(32);
const PIXEL = "pixel:APA91b" + "Q".repeat(140);
const SWEDE = "33".repeat(32);

const story = (id, minutesAgo, extra = {}) => ({
  id, title: "Kilde " + id, title_en: "Headline " + id, language_code: "no", country: "NO",
  source_name: "E24", published: new Date(NOW - minutesAgo * MIN).toISOString(), title_i18n: {}, ...extra,
});

function makeEnv(extra = {}) {
  return {
    DB: new FakeD1(),
    FEED_URL: FEED,
    FEED_FALLBACK_URL: "https://nordiccrypto.no/api/v1/news.json",
    APNS_TOPIC: "no.cryptonordic.tv",
    APNS_KEY_P8: keys.ecPem,
    APNS_KEY_ID: "KEYID12345",
    APNS_TEAM_ID: "YQBXSUUVJD",
    FCM_SERVICE_ACCOUNT_JSON: JSON.stringify({
      project_id: "nc-test", client_email: "push@nc-test.iam.gserviceaccount.com", private_key: keys.rsaPem,
      token_uri: "https://oauth2.googleapis.com/token",
    }),
    SENDS_PER_RUN: "40",
    ...extra,
  };
}

async function register(env, token, platform, countries, language, environment) {
  const res = await handleFetch(new Request("https://push.example/v1/devices", {
    method: "POST", body: JSON.stringify({ token, platform, countries, language, environment }),
  }), env, NOW);
  assert.equal(res.status, 200);
}

/** The network: the feed, Google's token endpoint, APNs and FCM. `apns`/`fcm` decide each push's response. */
function network(feedItems, { apns = () => [200, ""], fcm = () => [200, "{}"] } = {}) {
  const calls = [];
  let items = feedItems;
  let etag = 1;
  const fn = async (url, init = {}) => {
    calls.push({ url, init });
    if (url === FEED) {
      const tag = `"v${etag}"`;
      if (init.headers && init.headers["if-none-match"] === tag) return new Response(null, { status: 304 });
      return new Response(JSON.stringify({ items }), { status: 200, headers: { etag: tag } });
    }
    if (url === "https://oauth2.googleapis.com/token") {
      return new Response(JSON.stringify({ access_token: "ya29.test", expires_in: 3599 }), { status: 200 });
    }
    if (url.includes("push.apple.com/3/device/")) {
      const [status, body] = apns(url, init);
      return new Response(body, { status });
    }
    if (url.startsWith("https://fcm.googleapis.com/")) {
      const [status, body] = fcm(url, init);
      return new Response(body, { status });
    }
    return new Response("", { status: 404 });
  };
  fn.calls = calls;
  fn.publish = (next) => { items = next; etag++; };
  fn.pushes = () => calls.filter((c) => c.url.includes("push.apple.com") || c.url.startsWith("https://fcm."));
  return fn;
}

test("first run only learns; a new story goes once to each device that wants its country", async () => {
  const env = makeEnv();
  await register(env, IPHONE, "ios", ["NO", "SE"], "en");
  await register(env, MAC_DEV, "macos", ["NO"], "nb", "sandbox");
  await register(env, PIXEL, "android", ["NO"], "sv");
  await register(env, SWEDE, "ios", ["SE"], "sv");
  const net = network([story("old1", 600), story("old2", 900)]);

  const first = await runCron(env, NOW, net);
  assert.equal(first.queued, 0);
  assert.equal(net.pushes().length, 0);

  // Unchanged feed: a conditional request, nothing sent.
  const quiet = await runCron(env, NOW + 5 * MIN, net);
  assert.equal(quiet.feed, "not-modified");
  assert.equal(net.pushes().length, 0);

  net.publish([story("fresh", 3, { title_i18n: { sv: "Rubrik fresh" } }), story("old1", 600), story("old2", 900)]);
  const run = await runCron(env, NOW + 10 * MIN, net);
  assert.equal(run.queued, 1);
  assert.equal(run.sent, 3);
  const pushes = net.pushes();
  assert.equal(pushes.length, 3); // not the Swedish-only device

  const iphone = pushes.find((p) => p.url.endsWith(IPHONE));
  assert.ok(iphone.url.startsWith("https://api.push.apple.com/3/device/"));
  assert.equal(JSON.parse(iphone.init.body).aps.alert.body, "Headline fresh");
  assert.equal(JSON.parse(iphone.init.body).story, "fresh");
  const mac = pushes.find((p) => p.url.endsWith(MAC_DEV));
  assert.ok(mac.url.startsWith("https://api.sandbox.push.apple.com/3/device/"));
  assert.equal(JSON.parse(mac.init.body).aps.alert.body, "Kilde fresh"); // nb reader, Norwegian source
  assert.equal(JSON.parse(mac.init.body).aps.alert.title, "E24 · Norge");
  const pixel = pushes.find((p) => p.url.startsWith("https://fcm.googleapis.com/v1/projects/nc-test/messages:send"));
  assert.equal(pixel.init.headers.authorization, "Bearer ya29.test");
  const msg = JSON.parse(pixel.init.body).message;
  assert.equal(msg.token, PIXEL);
  assert.equal(msg.notification.body, "Rubrik fresh");

  // Nothing is sent twice.
  net.publish([story("fresh", 3), story("old1", 600), story("old2", 900)]);
  await runCron(env, NOW + 15 * MIN, net);
  assert.equal(net.pushes().length, 3);
  assert.equal(env.DB.rows("SELECT * FROM deliveries").length, 0);
});

test("dead tokens are removed, temporary failures are retried, then given up", async () => {
  const env = makeEnv();
  await register(env, IPHONE, "ios", ["NO"], "en");
  await register(env, MAC_DEV, "macos", ["NO"], "en");
  await register(env, PIXEL, "android", ["NO"], "en");
  const net = network([], {
    apns: (url) => url.endsWith(IPHONE) ? [410, '{"reason":"Unregistered"}'] : [503, ""],
    fcm: () => [404, '{"error":{"details":[{"errorCode":"UNREGISTERED"}]}}'],
  });
  await runCron(env, NOW, net);
  net.publish([story("s1", 1)]);
  const r = await runCron(env, NOW + 5 * MIN, net);
  assert.equal(r.removed, 2);
  assert.equal(r.retry, 1);
  assert.deepEqual(env.DB.rows("SELECT token FROM devices").map((d) => d.token), [MAC_DEV]);
  await runCron(env, NOW + 10 * MIN, net);
  await runCron(env, NOW + 15 * MIN, net);
  assert.equal(env.DB.rows("SELECT * FROM deliveries").length, 0); // three attempts, then dropped
  assert.equal(env.DB.rows("SELECT token FROM devices").length, 1); // a server error is not the device's fault
});

test("the APNs JWT and the FCM access token are reused between runs", async () => {
  const env = makeEnv();
  await register(env, IPHONE, "ios", ["NO"], "en");
  await register(env, PIXEL, "android", ["NO"], "en");
  const net = network([]);
  await runCron(env, NOW, net);
  net.publish([story("a", 1)]);
  await runCron(env, NOW + 5 * MIN, net);
  net.publish([story("b", 1), story("a", 6)]);
  await runCron(env, NOW + 10 * MIN, net);
  const auths = net.pushes().filter((p) => p.url.includes("apple")).map((p) => p.init.headers.authorization);
  assert.equal(auths.length, 2);
  assert.equal(auths[0], auths[1]);
  assert.equal(net.calls.filter((c) => c.url === "https://oauth2.googleapis.com/token").length, 1);
});

test("a rejected provider token is renewed on the next run", async () => {
  const env = makeEnv();
  await register(env, IPHONE, "ios", ["NO"], "en");
  let reject = true;
  const net = network([], { apns: () => (reject ? [403, '{"reason":"ExpiredProviderToken"}'] : [200, ""]) });
  await runCron(env, NOW, net);
  net.publish([story("a", 1)]);
  await runCron(env, NOW + 5 * MIN, net);
  assert.equal(env.DB.rows("SELECT * FROM state WHERE key = 'apns_jwt'").length, 0);
  reject = false;
  const r = await runCron(env, NOW + 6 * MIN, net);
  assert.equal(r.sent, 1);
});

test("SENDS_PER_RUN caps the pushes per run; the rest go next run", async () => {
  const env = makeEnv({ SENDS_PER_RUN: "2" });
  for (let i = 0; i < 5; i++) await register(env, String(i).repeat(64), "ios", ["NO"], "en");
  const net = network([]);
  await runCron(env, NOW, net);
  net.publish([story("x", 1)]);
  assert.equal((await runCron(env, NOW + 5 * MIN, net)).sent, 2);
  assert.equal((await runCron(env, NOW + 10 * MIN, net)).sent, 2);
  assert.equal((await runCron(env, NOW + 15 * MIN, net)).sent, 1);
  assert.equal(net.pushes().length, 5);
});

test("without credentials nothing is sent and the queue expires", async () => {
  const env = makeEnv({ APNS_KEY_P8: "", FCM_SERVICE_ACCOUNT_JSON: "" });
  await register(env, IPHONE, "ios", ["NO"], "en");
  const net = network([]);
  await runCron(env, NOW, net);
  net.publish([story("x", 1)]);
  await runCron(env, NOW + 5 * MIN, net);
  assert.equal(net.pushes().length, 0);
  await runCron(env, NOW + 7 * 3600e3, net);
  assert.equal(env.DB.rows("SELECT * FROM deliveries").length, 0);
});

test("old stories, floods and devices that stopped checking in", async () => {
  const env = makeEnv();
  await register(env, IPHONE, "ios", ["NO"], "en");
  const net = network([]);
  await runCron(env, NOW, net);
  // A backfilled story from last week is remembered but not announced.
  net.publish([story("lastweek", 7 * 24 * 60)]);
  assert.equal((await runCron(env, NOW + 5 * MIN, net)).queued, 0);
  // Eleven new stories at once looks like a reset: remembered, not announced.
  net.publish(Array.from({ length: 11 }, (_, i) => story("burst" + i, 1)));
  assert.equal((await runCron(env, NOW + 10 * MIN, net)).queued, 0);
  assert.equal(net.pushes().length, 0);
  // 180 days without an update: the device is forgotten.
  await runCron(env, NOW + 181 * 24 * 3600e3, net);
  assert.equal(env.DB.rows("SELECT * FROM devices").length, 0);
});

const publishReq = (token) => new Request("https://push.example/v1/publish", {
  method: "POST", headers: token ? { authorization: "Bearer " + token } : {},
});

test("POST /v1/publish runs a check right away, only with the publish token", async () => {
  const env = makeEnv({ PUSH_PUBLISH_TOKEN: "s3cret-token" });
  await register(env, IPHONE, "ios", ["NO"], "en");
  const net = network([story("old1", 600)]);
  await runCron(env, NOW, net);
  net.publish([story("fresh", 2, { html_url: "https://nordiccrypto.no/news/fresh/" }), story("old1", 600)]);

  assert.equal((await handleFetch(publishReq(), env, NOW + MIN, net)).status, 401);
  assert.equal((await handleFetch(publishReq("wrong"), env, NOW + MIN, net)).status, 401);
  assert.equal((await handleFetch(new Request("https://push.example/v1/publish"), env, NOW + MIN, net)).status, 405);
  assert.equal(net.pushes().length, 0);

  const res = await handleFetch(publishReq("s3cret-token"), env, NOW + MIN, net);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.queued, 1);
  assert.equal(body.sent, 1);
  const sent = JSON.parse(net.pushes()[0].init.body);
  assert.equal(sent.story, "fresh");
  assert.equal(sent.url, "https://nordiccrypto.no/news/fresh/");

  // A second call for the same publish sends nothing.
  await handleFetch(publishReq("s3cret-token"), env, NOW + 2 * MIN, net);
  assert.equal(net.pushes().length, 1);

  const off = makeEnv();
  assert.equal((await handleFetch(publishReq("anything"), off, NOW, net)).status, 503);
  const health = await (await handleFetch(new Request("https://push.example/v1/health"), env, NOW)).json();
  assert.equal(health.publish, true);
});

test("one publish sends at most one notification per device: the newest story in its countries", async () => {
  const env = makeEnv({ PUSH_LANGUAGE: "en" });
  await register(env, IPHONE, "ios", ["NO", "SE"], "sv");
  await register(env, SWEDE, "ios", ["SE"], "sv");
  await register(env, PIXEL, "android", ["NO"], "nb");
  const net = network([]);
  await runCron(env, NOW, net);
  net.publish([
    story("no-older", 30),
    story("se-new", 5, { country: "SE", language_code: "sv", title: "Svensk rubrik", title_i18n: { sv: "Svensk rubrik" } }),
    story("no-newest", 1),
  ]);
  const run = await runCron(env, NOW + 5 * MIN, net);
  assert.equal(run.queued, 3);
  assert.equal(run.sent, 3);
  const pushes = net.pushes();
  assert.equal(pushes.length, 3);
  assert.equal(JSON.parse(pushes.find((p) => p.url.endsWith(IPHONE)).init.body).story, "no-newest");
  const swede = JSON.parse(pushes.find((p) => p.url.endsWith(SWEDE)).init.body);
  assert.equal(swede.story, "se-new");
  // PUSH_LANGUAGE=en: the English headline and country name, whatever the device language.
  assert.equal(swede.aps.alert.body, "Headline se-new");
  assert.equal(swede.aps.alert.title, "E24 · Sweden");
  const pixel = JSON.parse(pushes.find((p) => p.url.startsWith("https://fcm.")).init.body).message;
  assert.equal(pixel.data.story, "no-newest");
  assert.equal(pixel.notification.body, "Headline no-newest");
  assert.equal(env.DB.rows("SELECT * FROM deliveries").length, 0);
});
