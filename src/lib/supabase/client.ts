import { createBrowserClient } from "@supabase/ssr";
import type { Database } from "@/types/database";

/**
 * Supabase client for use in Client Components (the browser).
 * Reads the two public, safe-to-expose env vars — see .env.example.
 *
 * Not called anywhere yet in Phase 1 (there's no UI that talks to Supabase
 * yet), but the helper is here so Phase 2's auth/data work has a correct,
 * ready-made starting point instead of reinventing this per-component.
 */
export function createClient() {
  return createBrowserClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
  );
}
