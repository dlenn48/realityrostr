import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { signOut } from "./actions/auth";

const builtItems = [
  "Next.js + TypeScript + Tailwind app",
  "Live Supabase project: schema, RLS, and Data API grants",
  "Magic-link sign-in",
];

const notYetItems = [
  "Dashboard, leagues, rosters, standings UI",
  "Admin console",
  "Real Survivor/Traitors show data",
];

export default async function Home() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col justify-center gap-8 px-6 py-16">
      <div>
        <p className="text-sm font-medium tracking-wide text-indigo-600 uppercase">
          Phase 2 — Supabase &amp; Auth
        </p>
        <h1 className="mt-2 text-4xl font-bold">RealityRostr</h1>
        <p className="mt-3 text-base text-neutral-600 dark:text-neutral-400">
          Fantasy leagues for reality competition TV. This page confirms the
          app builds, runs, and can authenticate against a real Supabase
          project — the real experience comes in later phases.
        </p>
      </div>

      <div className="rounded-md border border-neutral-200 p-4 text-sm dark:border-neutral-800">
        {user ? (
          <div className="flex items-center justify-between gap-4">
            <span>
              Signed in as <strong>{user.email}</strong>
            </span>
            <form action={signOut}>
              <button
                type="submit"
                className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm hover:bg-neutral-100 dark:border-neutral-700 dark:hover:bg-neutral-900"
              >
                Sign out
              </button>
            </form>
          </div>
        ) : (
          <div className="flex items-center justify-between gap-4">
            <span>Not signed in.</span>
            <Link
              href="/login"
              className="rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-indigo-500"
            >
              Sign in
            </Link>
          </div>
        )}
      </div>

      <div className="grid gap-6 sm:grid-cols-2">
        <div>
          <h2 className="text-sm font-semibold text-neutral-500 uppercase">
            Built so far
          </h2>
          <ul className="mt-2 space-y-1 text-sm">
            {builtItems.map((item) => (
              <li key={item} className="flex gap-2">
                <span aria-hidden className="text-green-600">
                  ✓
                </span>
                {item}
              </li>
            ))}
          </ul>
        </div>
        <div>
          <h2 className="text-sm font-semibold text-neutral-500 uppercase">
            Coming in later phases
          </h2>
          <ul className="mt-2 space-y-1 text-sm text-neutral-500">
            {notYetItems.map((item) => (
              <li key={item} className="flex gap-2">
                <span aria-hidden>–</span>
                {item}
              </li>
            ))}
          </ul>
        </div>
      </div>
    </main>
  );
}
