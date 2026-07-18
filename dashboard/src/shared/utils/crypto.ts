export const sha256 = async (value: string): Promise<string> => {
  if (!value) return "";
  if (!globalThis.crypto?.subtle) {
    throw new Error("crypto.subtle not available");
  }
  const encoder = new TextEncoder();
  const data = encoder.encode(value);
  const hashBuffer = await globalThis.crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hashBuffer))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
};
