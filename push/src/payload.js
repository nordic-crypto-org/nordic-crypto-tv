// What a notification says: the story's headline in the device's language,
// with "Source · Country" above it, the same as the apps' own notifications.
import { COUNTRY_NAMES, LANGS } from "./copy.js";

const NORSK = new Set(["no", "nb", "nn"]);
const sameFamily = (a, b) => a === b || (NORSK.has(a) && NORSK.has(b));

function text(v) {
  return typeof v === "string" ? v.replace(/\s+/g, " ").trim() : "";
}

export function clip(s, n) {
  const t = text(s);
  if (t.length <= n) return t;
  const cut = t.slice(0, n - 1).replace(/\s+\S*$/, "");
  return (cut || t.slice(0, n - 1)) + "…";
}

export function cleanLang(lang) {
  return LANGS.includes(lang) ? lang : "en";
}

/**
 * The headline for a reader of `lang`: the source headline when it is already in
 * that language (nb/nn/no count as one), else our translation (title_i18n),
 * else our English headline (title_en), else the source headline.
 */
export function headline(item, lang) {
  const l = cleanLang(lang);
  const title = text(item.title);
  if (item.language_code && sameFamily(item.language_code, l)) return title || text(item.title_en);
  const own = item.title_i18n && typeof item.title_i18n === "object" ? text(item.title_i18n[l]) : "";
  return own || text(item.title_en) || title;
}

export function countryName(code, lang) {
  return (COUNTRY_NAMES[cleanLang(lang)] || COUNTRY_NAMES.en)[code] || null;
}

export function notificationText(item, lang) {
  const parts = [text(item.source_name), countryName(item.country, lang)].filter(Boolean);
  return {
    title: clip(parts.join(" · ") || "Nordic Crypto", 80),
    body: clip(headline(item, lang), 180),
  };
}

/** APNs JSON. `story` is what the app opens when the notification is tapped. */
export function apnsPayload(item, lang) {
  const { title, body } = notificationText(item, lang);
  return {
    aps: {
      alert: { title, body },
      sound: "default",
      "thread-id": item.country || "news",
    },
    story: item.id,
    ...(item.url ? { url: item.url } : {}),
  };
}

/** FCM HTTP v1 `message`. Tapping it opens the launcher activity with the data as extras ("story"). */
export function fcmMessage(token, item, lang) {
  const { title, body } = notificationText(item, lang);
  return {
    token,
    notification: { title, body },
    data: { story: String(item.id), country: String(item.country || ""), ...(item.url ? { url: String(item.url) } : {}) },
    android: {
      ttl: "21600s",
      collapse_key: String(item.id).slice(0, 64),
      notification: { channel_id: "new-stories", tag: "story-" + item.id, icon: "ic_notification" },
    },
  };
}
