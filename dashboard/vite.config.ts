import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";
import path from "node:path";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");

  return {
    plugins: [react()],
    resolve: {
      alias: {
        "@core": path.resolve(__dirname, "src/core"),
        "@domain": path.resolve(__dirname, "src/domain"),
        "@application": path.resolve(__dirname, "src/application"),
        "@infrastructure": path.resolve(__dirname, "src/infrastructure"),
        "@presentation": path.resolve(__dirname, "src/presentation"),
        "@shared": path.resolve(__dirname, "src/shared")
      }
    },
    // ── Security Hardening ──────────────────────────────────────
    build: {
      // NEVER expose source maps in production
      sourcemap: false,
      // Advanced minification to resist reverse engineering
      minify: "terser",
      terserOptions: {
        compress: {
          drop_console: false,    // Preserve console.* for observability (do not strip)
          drop_debugger: false,   // Preserve debugger statements so production debugging is possible when needed
          passes: 1               // Single pass compression
        },
        mangle: {
          toplevel: true
        },
        format: {
          comments: true         // Keep comments to avoid losing context and to aid debugging
        }
      },
      // Split chunks for better caching + harder to reconstruct
      rollupOptions: {
        output: {
          manualChunks: {
            vendor: ["react", "react-dom", "react-router-dom"],
            supabase: ["@supabase/supabase-js"],
            ui: ["lucide-react"]
          },
          // Randomize chunk names to make mapping harder
          chunkFileNames: "assets/c-[hash].js",
          entryFileNames: "assets/e-[hash].js",
          assetFileNames: "assets/a-[hash][extname]"
        }
      },
      // Target modern browsers only
      target: "es2020",
      cssMinify: true
    },
    // Expose both VITE_ and legacy unprefixed Supabase vars at build time.
    // This keeps production working even if the host was configured with
    // SUPABASE_URL / SUPABASE_ANON_KEY instead of the Vite-prefixed names.
    define: {
      __APP_VERSION__: JSON.stringify(process.env.npm_package_version || "0.0.0"),
      __BUILD_TIME__: JSON.stringify(new Date().toISOString()),
      __SUPABASE_URL__: JSON.stringify(env.VITE_SUPABASE_URL || env.SUPABASE_URL || ""),
      __SUPABASE_ANON_KEY__: JSON.stringify(env.VITE_SUPABASE_ANON_KEY || env.SUPABASE_ANON_KEY || "")
    },
    server: {
      // Dev server security
      headers: {
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY"
      }
    }
  };
});
