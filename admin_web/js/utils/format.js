export function pick(source, keys) {
  for (const key of keys) {
    const value = source?.[key];
    if (value !== undefined && value !== null && value !== "") return value;
  }
  return undefined;
}

export function asNumber(value) {
  if (typeof value === "number") return value;
  if (typeof value === "string") {
    const parsed = Number(value.replace("S/", "").replaceAll(",", "").trim());
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

export function joinName(names, lastNames) {
  return [names, lastNames].filter(Boolean).join(" ").trim();
}

export function normalizeText(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .trim()
    .toLowerCase();
}

export function formatCurrency(value) {
  const amount = asNumber(value);
  return new Intl.NumberFormat("es-PE", {
    style: "currency",
    currency: "PEN",
  }).format(amount);
}

export function toMillis(value) {
  if (!value) return 0;
  if (typeof value.toDate === "function") return value.toDate().getTime();
  if (typeof value.seconds === "number") return value.seconds * 1000;
  if (value instanceof Date) return value.getTime();
  if (typeof value === "string") return Date.parse(value) || 0;
  return 0;
}

export function formatDate(value) {
  const millis = toMillis(value);
  if (!millis) return "Sin fecha";
  return new Intl.DateTimeFormat("es-PE", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(millis));
}

export function formatInputDate(value) {
  const millis = toMillis(value);
  if (!millis) return "";
  const date = new Date(millis);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

export function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

export function escapeAttr(value) {
  return escapeHtml(value).replaceAll("`", "&#096;");
}
