import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

/**
 * Refreshes the Supabase auth session on every request (except static
 * assets). Without this, a signed-in user's session can go stale between
 * page loads — only a Proxy response can write a refreshed session cookie
 * back to the browser before a Server Component ever runs.
 *
 * Must be named `proxy.ts` at this location (src/proxy.ts, alongside
 * src/app) — Next.js 16 renamed the `middleware.ts` file convention to
 * `proxy.ts`. See
 * https://nextjs.org/docs/app/api-reference/file-conventions/proxy.
 */
export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value),
          );
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  // Don't add logic between createServerClient() and getUser() — this call
  // is what actually triggers a token refresh when the session is stale.
  await supabase.auth.getUser();

  return response;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
