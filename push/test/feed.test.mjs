import { test } from "node:test";
import assert from "node:assert/strict";
import { fetchFeed, newStories, normalizeItems } from "../src/feed.js";

const NOW = Date.parse("2026-10-11T12:00:00Z");
const item = (id, hoursAgo, extra = {}) => ({
  id, title: "T " + id, country: "NO", published: new Date(NOW - hoursAgo * 3600e3).toISOString(), ...extra,
});

test("normalizeItems keeps only what a notification needs and drops bad rows", () => {
  const items = normalizeItems({
    items: [
      { ...item("a1", 1), title_en: "E", title_i18n: { sv: "S", bad_key: "x", fi: "" }, summary: "not kept", coverage: {},
        html_url: "https://nordiccrypto.no/news/a1/" },
      { id: "../etc", title: "bad id" },
      { id: "b2" },
      null,
    ],
  });
  assert.equal(items.length, 1);
  assert.deepEqual(Object.keys(items[0]).sort(), ["country", "id", "language_code", "published", "source_name", "title", "title_en", "title_i18n", "url"]);
  assert.deepEqual(items[0].title_i18n, { sv: "S" });
  assert.equal(items[0].url, "https://nordiccrypto.no/news/a1/");
  assert.equal(normalizeItems({ items: [{ ...item("x", 1), html_url: "javascript:alert(1)" }] })[0].url, null);
  assert.equal(normalizeItems({ items: Array.from({ length: 60 }, (_, i) => item("n" + i, 1)) }).length, 25);
  assert.deepEqual(normalizeItems(null), []);
});

test("newStories: unseen, recent, and not a flood", () => {
  const items = [item("new1", 1), item("seen", 2), item("old", 72), { id: "nodate", title: "x" }];
  const r = newStories(items, new Set(["seen"]), NOW);
  assert.deepEqual(r.unseen.map((i) => i.id), ["new1", "old", "nodate"]);
  assert.deepEqual(r.announce.map((i) => i.id), ["new1", "nodate"]);
  const flood = Array.from({ length: 11 }, (_, i) => item("f" + i, 1));
  const f = newStories(flood, new Set(), NOW);
  assert.equal(f.unseen.length, 11);
  assert.equal(f.announce.length, 0);
});

function fakeFetch(routes) {
  const calls = [];
  const fn = async (url, init) => {
    calls.push({ url, headers: init.headers });
    const r = routes[url];
    if (!r) return new Response("nope", { status: 404 });
    return typeof r === "function" ? r(init) : r.clone();
  };
  fn.calls = calls;
  return fn;
}

const env = { FEED_URL: "https://x/api/v1/news/latest.json", FEED_FALLBACK_URL: "https://x/api/v1/news.json" };

test("fetchFeed sends If-None-Match and understands 304", async () => {
  const f = fakeFetch({
    [env.FEED_URL]: (init) => init.headers["if-none-match"] === '"e1"'
      ? new Response(null, { status: 304 })
      : new Response(JSON.stringify({ items: [item("a", 1)] }), { status: 200, headers: { etag: '"e1"' } }),
  });
  const first = await fetchFeed(env, {}, f);
  assert.equal(first.status, "ok");
  assert.equal(first.etag, '"e1"');
  assert.equal(first.items[0].id, "a");
  const second = await fetchFeed(env, { [env.FEED_URL]: '"e1"' }, f);
  assert.equal(second.status, "not-modified");
  assert.equal(f.calls[1].headers["if-none-match"], '"e1"');
});

test("fetchFeed falls back to news.json while latest.json is missing", async () => {
  const f = fakeFetch({ [env.FEED_FALLBACK_URL]: new Response(JSON.stringify({ items: [item("full", 1)] }), { status: 200 }) });
  const r = await fetchFeed(env, {}, f);
  assert.equal(r.status, "ok");
  assert.equal(r.url, env.FEED_FALLBACK_URL);
  assert.deepEqual(f.calls.map((c) => c.url), [env.FEED_URL, env.FEED_FALLBACK_URL]);
  const down = await fetchFeed(env, {}, async () => new Response("", { status: 503 }));
  assert.deepEqual(down, { status: "error", code: 503 });
  const thrown = await fetchFeed(env, {}, async () => { throw new Error("offline"); });
  assert.equal(thrown.status, "error");
});
