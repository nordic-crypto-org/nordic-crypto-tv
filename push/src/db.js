// D1 queries. Everything the Worker stores goes through here.
import { countriesColumn } from "./devices.js";

export const DELIVERY_TTL_MS = 6 * 3600 * 1000;
export const STORY_TTL_MS = 30 * 24 * 3600 * 1000;
export const DEVICE_TTL_MS = 180 * 24 * 3600 * 1000;
export const MAX_ATTEMPTS = 3;

export async function getState(db, key) {
  const row = await db.prepare("SELECT value FROM state WHERE key = ?").bind(key).first();
  return row ? row.value : null;
}

export function setStateStmt(db, key, value) {
  return db.prepare("INSERT INTO state (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value").bind(key, value);
}

export async function setState(db, key, value) {
  await setStateStmt(db, key, value).run();
}

export async function upsertDevice(db, d) {
  await db.prepare(
    "INSERT INTO devices (token, platform, environment, language, countries, updated_at) VALUES (?, ?, ?, ?, ?, ?) "
    + "ON CONFLICT(token) DO UPDATE SET platform = excluded.platform, environment = excluded.environment, "
    + "language = excluded.language, countries = excluded.countries, updated_at = excluded.updated_at",
  ).bind(d.token, d.platform, d.environment, d.language, countriesColumn(d.countries), d.updated_at).run();
}

export async function deleteDevice(db, token) {
  const res = await db.batch([
    db.prepare("DELETE FROM deliveries WHERE token = ?").bind(token),
    db.prepare("DELETE FROM devices WHERE token = ?").bind(token),
  ]);
  return Boolean(res[1] && res[1].meta && res[1].meta.changes);
}

export async function seenIds(db, ids) {
  if (!ids.length) return new Set();
  const marks = ids.map(() => "?").join(",");
  const { results } = await db.prepare(`SELECT id FROM stories WHERE id IN (${marks})`).bind(...ids).all();
  return new Set(results.map((r) => r.id));
}

const publishedMs = (s) => {
  const t = s.published ? Date.parse(s.published) : NaN;
  return Number.isNaN(t) ? Infinity : t; // undated counts as newest, as in newStories
};

/**
 * Remembers stories as seen and queues the ones in `announce`. A device gets at
 * most one notification per run (one run = one publish): the newest announced
 * story in one of its countries. The other new stories are only remembered.
 */
export async function recordStories(db, unseen, announce, nowMs) {
  const queue = new Set(announce.map((s) => s.id));
  const stmts = [];
  for (const s of unseen) {
    stmts.push(db.prepare("INSERT OR IGNORE INTO stories (id, seen_at, item) VALUES (?, ?, ?)")
      .bind(s.id, nowMs, queue.has(s.id) ? JSON.stringify(s) : null));
  }
  const newestFirst = [...announce].sort((a, b) => publishedMs(b) - publishedMs(a));
  for (const s of newestFirst) {
    if (!s.country) continue;
    stmts.push(db.prepare(
      "INSERT OR IGNORE INTO deliveries (story_id, token, queued_at) "
      + "SELECT ?, token, ? FROM devices WHERE instr(countries, ?) > 0 "
      + "AND token NOT IN (SELECT token FROM deliveries WHERE queued_at = ?)",
    ).bind(s.id, nowMs, "," + s.country + ",", nowMs));
  }
  if (stmts.length) await db.batch(stmts);
}

/** The oldest queued notifications that are still fresh, with what is needed to send them. */
export async function pendingDeliveries(db, nowMs, limit) {
  const { results } = await db.prepare(
    "SELECT d.story_id, d.token, d.attempts, v.platform, v.environment, v.language, s.item "
    + "FROM deliveries d JOIN devices v ON v.token = d.token JOIN stories s ON s.id = d.story_id "
    + "WHERE d.queued_at > ? AND s.item IS NOT NULL ORDER BY d.queued_at, d.story_id LIMIT ?",
  ).bind(nowMs - DELIVERY_TTL_MS, limit).all();
  return results;
}

/** Applies send results: done rows go, dead tokens go, retries count up (and go after MAX_ATTEMPTS). */
export async function settle(db, outcomes) {
  const stmts = [];
  for (const o of outcomes) {
    if (o.result === "remove") {
      stmts.push(db.prepare("DELETE FROM deliveries WHERE token = ?").bind(o.token));
      stmts.push(db.prepare("DELETE FROM devices WHERE token = ?").bind(o.token));
    } else if (o.result === "retry" || o.result === "auth" || o.result === "skip") {
      stmts.push(db.prepare("UPDATE deliveries SET attempts = attempts + 1 WHERE story_id = ? AND token = ?").bind(o.story_id, o.token));
    } else {
      stmts.push(db.prepare("DELETE FROM deliveries WHERE story_id = ? AND token = ?").bind(o.story_id, o.token));
    }
  }
  if (stmts.length) await db.batch(stmts);
}

/** Housekeeping: expired or exhausted deliveries, old stories, devices that stopped checking in. */
export async function prune(db, nowMs) {
  await db.batch([
    db.prepare("DELETE FROM deliveries WHERE queued_at <= ? OR attempts >= ?").bind(nowMs - DELIVERY_TTL_MS, MAX_ATTEMPTS),
    db.prepare("UPDATE stories SET item = NULL WHERE item IS NOT NULL AND seen_at <= ?").bind(nowMs - DELIVERY_TTL_MS),
    db.prepare("DELETE FROM stories WHERE seen_at <= ?").bind(nowMs - STORY_TTL_MS),
    db.prepare("DELETE FROM deliveries WHERE token IN (SELECT token FROM devices WHERE updated_at <= ?)").bind(nowMs - DEVICE_TTL_MS),
    db.prepare("DELETE FROM devices WHERE updated_at <= ?").bind(nowMs - DEVICE_TTL_MS),
  ]);
}
