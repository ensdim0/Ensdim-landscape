/**
 * Compress an image file using canvas.
 * Returns a compressed Blob when possible.
 * Falls back to the original file if the browser cannot decode it.
 */
export async function compressImage(
  file: File,
  maxWidth = 1200,
  maxHeight = 1200,
  quality = 0.6
): Promise<Blob> {
  return new Promise((resolve) => {
    const img = new Image();
    const url = URL.createObjectURL(file);

    const fallbackToOriginal = () => {
      URL.revokeObjectURL(url);
      resolve(file);
    };

    img.onload = () => {
      URL.revokeObjectURL(url);

      let { width, height } = img;

      if (width > maxWidth || height > maxHeight) {
        const ratio = Math.min(maxWidth / width, maxHeight / height);
        width = Math.round(width * ratio);
        height = Math.round(height * ratio);
      }

      const canvas = document.createElement("canvas");
      canvas.width = width;
      canvas.height = height;

      const ctx = canvas.getContext("2d");
      if (!ctx) {
        fallbackToOriginal();
        return;
      }

      try {
        ctx.drawImage(img, 0, 0, width, height);
      } catch {
        fallbackToOriginal();
        return;
      }

      canvas.toBlob(
        (blob) => {
          if (blob) resolve(blob);
          else fallbackToOriginal();
        },
        "image/jpeg",
        quality
      );
    };

    img.onerror = fallbackToOriginal;
    img.src = url;
  });
}
