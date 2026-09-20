const foundationItems = [
  "Next.js + TypeScript + Tailwind app",
  "Database schema & Row Level Security designed",
  "Supabase client helpers (browser + server)",
  "Environment variable handling",
];

const notYetItems = [
  "Sign in / authentication flows",
  "Dashboard, leagues, rosters, standings UI",
  "Admin console",
];

export default function Home() {
  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col justify-center gap-8 px-6 py-16">
      <div>
        <p className="text-sm font-medium tracking-wide text-indigo-600 uppercase">
          Phase 1 — Foundation
        </p>
        <h1 className="mt-2 text-4xl font-bold">RealityRostr</h1>
        <p className="mt-3 text-base text-neutral-600 dark:text-neutral-400">
          Fantasy leagues for reality competition TV. This page just confirms
          the application builds and runs — the real experience comes in
          later phases.
        </p>
      </div>

      <div className="grid gap-6 sm:grid-cols-2">
        <div>
          <h2 className="text-sm font-semibold text-neutral-500 uppercase">
            Built in Phase 1
          </h2>
          <ul className="mt-2 space-y-1 text-sm">
            {foundationItems.map((item) => (
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
