/**
 * Input sanitization utilities to prevent XSS, injection attacks,
 * and strip dangerous content from user inputs.
 */

const HTML_ENTITIES: Record<string, string> = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#x27;",
  "/": "&#x2F;",
  "`": "&#96;"
};

const ENTITY_REGEX = /[&<>"'`/]/g;

/**
 * Escape HTML special characters to prevent XSS in rendered content.
 */
export const escapeHtml = (str: string): string => {
  return str.replace(ENTITY_REGEX, (char) => HTML_ENTITIES[char] || char);
};

/**
 * Strip all HTML tags from input text.
 */
export const stripHtml = (str: string): string => {
  return str.replace(/<[^>]*>/g, "");
};

/**
 * Sanitize a plain text input: trim, strip HTML, limit length.
 */
export const sanitizeText = (input: string, maxLength = 500): string => {
  if (!input || typeof input !== "string") return "";
  return stripHtml(input).trim().slice(0, maxLength);
};


export const sanitizeEmail = (email: string): string => {
  if (!email || typeof email !== "string") return "";
  const cleaned = email.trim().toLowerCase().slice(0, 254);
  const emailRegex = /^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$/;
  return emailRegex.test(cleaned) ? cleaned : "";
};

export const sanitizeIdentifier = (identifier: string): string => {
  if (!identifier || typeof identifier !== "string") return "";
  const cleaned = identifier.trim().toLowerCase().slice(0, 254);
  // If it contains '@', validate as email, else assume it's a phone/identifier
  if (cleaned.includes('@')) {
    const emailRegex = /^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$/;
    return emailRegex.test(cleaned) ? cleaned : "";
  }
  // Remove non-alphanumeric just to be safe for phone/usernames
  return cleaned.replace(/[^a-z0-9+_-]/g, '');
};


export const sanitizeSearch = (query: string, maxLength = 200): string => {
  if (!query || typeof query !== "string") return "";
  return query
    .replace(/[<>'"`;\\]/g, "")
    .replace(/(\b(SELECT|INSERT|UPDATE|DELETE|DROP|UNION|ALTER|CREATE|EXEC)\b)/gi, "")
    .trim()
    .slice(0, maxLength);
};


export const sanitizeNumber = (value: unknown, defaultVal = 0): number => {
  const num = typeof value === "string" ? parseFloat(value) : Number(value);
  return Number.isFinite(num) ? num : defaultVal;
};


export const sanitizeUUID = (id: string): string | null => {
  if (!id || typeof id !== "string") return null;
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(id.trim()) ? id.trim().toLowerCase() : null;
};


export const sanitizeObject = <T extends Record<string, unknown>>(obj: T): T => {
  const result = { ...obj };
  for (const key in result) {
    const val = result[key];
    if (typeof val === "string") {
      (result as any)[key] = sanitizeText(val, 2000);
    } else if (typeof val === "object" && val !== null && !Array.isArray(val)) {
      (result as any)[key] = sanitizeObject(val as Record<string, unknown>);
    }
  }
  return result;
};
