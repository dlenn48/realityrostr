import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import type { Database } from "@/types/database";

/**
 * Supabase client for use in Server Components, Route Handlers, and Server
 * Actions. Wires cookie reads/writes through Next's `cookies()` API so an
 * authenticated session set in the browser is visible on the server.
 *
 * Not called anywhere yet in Phase 1 — there is no server-rendered page that
 * needs a session yet — but the helper is ready for Phase 2's auth work.
 *
 * NOTE: a Server Component can read cookies but not write them, so `setAll`
 * below can throw when called from one. That's expected and safe to ignore
 * as long as a session-refreshing proxy/middleware (Phase 2) is also in
 * place — see https://supabase.com/docs/guides/auth/server-side/nextjs.
 */
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {
            // Called from a Server Component — safe to ignore as long as
            // session refresh is handled elsewhere (Phase 2).
          }
        },
      },
    },
  );
}
