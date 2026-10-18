// Reads the public news API and works out which stories are new.
export const LATEST_LIMIT = 25;
export const MAX_AGE_HOURS = 48;   // older stories that appear late (backfill) are not announced
export const MAX_NEW_PER_RUN = 10; // more than this at once looks like a reset, not news

const ID = /^[A-Za-z0-9_-]{1,64}$/;

function httpsUrl(v) {
  return typeof v === "string" && /^https:\/\/[^\s]{1,500}$/.test(v.trim()) ? v.trim() : null;
}

function str(v, max) {
  return typeof v === "string" && v.trim() ? v.trim().slice(0, max) : null;
}

/** The fields a notification needs, from either latest.json or the full news.json. */
export function normalizeItems(doc, limit = LATEST_LIMIT) {
  const raw = doc && Array.isArray(doc.items) ? doc.items : [];
  const out = [];
  for (const r of raw) {
    if (out.length >= limit) break;
    if (!r || typeof r !== "object" || typeof r.id !== "string" || !ID.test(r.id)) continue;
    const title = str(r.title, 400);
    if (!title) continue;
    const i18n = {};
    if (r.title_i18n && typeof r.title_i18n === "object") {
      for (const [k, v] of Object.entries(r.title_i18n)) {
        if (/^[a-z]{2}$/.test(k) && str(v, 400)) i18n[k] = str(v, 400);
      }
    }
    out.push({
      id: r.id,
      published: str(r.published, 40),
      country: str(r.country, 8),
      source_name: str(r.source_name, 80),
      language_code: str(r.language_code, 8),
      title,
      title_en: str(r.title_en, 400),
      title_i18n: i18n,
      url: httpsUrl(r.html_url),
    });
  }
  return out;
}

/**
 * New stories: not seen before and published in the last MAX_AGE_HOURS
 * (a story without a date counts as new). Returns the ones to announce,
 * newest first, at most MAX_NEW_PER_RUN.
 */
export function newStories(items, seen, nowMs, { maxAgeHours = MAX_AGE_HOURS, maxNew = MAX_NEW_PER_RUN } = {}) {
  const unseen = items.filter((i) => !seen.has(i.id));
  const recent = unseen.filter((i) => {
    const t = i.published ? Date.parse(i.published) : NaN;
    return Number.isNaN(t) || nowMs - t <= maxAgeHours * 3600 * 1000;
  });
  return { unseen, announce: recent.length > maxNew ? [] : recent };
}

/**
 * Conditional GET of the feed. 404 on latest.json (not deployed yet) falls back to news.json.
 * Returns {status: "not-modified"} | {status: "ok", items, etag} | {status: "error", code}.
 */
export async function fetchFeed(env, etags, fetchImpl = fetch) {
  const urls = [env.FEED_URL, env.FEED_FALLBACK_URL].filter(Boolean);
  for (const url of urls) {
    const headers = { accept: "application/json", "user-agent": "nordic-crypto-app-push/1" };
    if (etags[url]) headers["if-none-match"] = etags[url];
    let res;
    try {
      res = await fetchImpl(url, { headers });
    } catch {
      return { status: "error", code: 0 };
    }
    if (res.status === 404 && url !== urls[urls.length - 1]) continue;
    if (res.status === 304) return { status: "not-modified", url };
    if (!res.ok) return { status: "error", code: res.status };
    try {
      const doc = await res.json();
      return { status: "ok", url, etag: res.headers.get("etag"), items: normalizeItems(doc) };
    } catch {
      return { status: "error", code: res.status };
    }
  }
  return { status: "error", code: 404 };
}
