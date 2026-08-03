# Orbit — Frontend (React + Vite PWA)

The Orbit subscription-tracker app: same UI/UX and design language as
[tryorbit.com](https://tryorbit.com), the signature **orbit animation**, and
**Magic Import** — an installable PWA that feels native on the Home Screen.
All brand assets are original recreations.

## Architecture

Feature-based, with a clean data layer and a `@/` → `src/` path alias.

```
src/
├── app/                 App shell — tab nav, bottom sheet, install prompt
├── components/ui/       Shared primitives: Planet, OrbitHero, TabBar, Sheet
├── features/            Self-contained features, each with a barrel index.ts
│   ├── subscriptions/   SubscriptionsScreen · SubscriptionForm · SubscriptionDetail
│   ├── calendar/        CalendarScreen
│   ├── insights/        InsightsScreen
│   ├── settings/        SettingsScreen
│   └── import/          MagicImportScreen
├── data/                State + persistence
│   ├── store.tsx        sync-aware store (React context)
│   ├── localStore.ts    localStorage cache / offline source of truth
│   ├── seed.ts          demo data
│   └── api/             client.ts + subscriptionsApi.ts (case-mapped)
├── lib/                 Pure domain: types, money math, catalog, env
└── styles/              global.css design tokens
```

**Data flow:** components → `useStore()` → optimistic local update + write-through
to the API. localStorage is only an **offline cache** for the installed PWA —
the durable source of truth is the backend (Supabase). When sync is enabled,
every change writes through to the API.

## Run

```bash
cd frontend
npm install
npm run dev       # http://localhost:5173

npm run build     # production build + service worker → dist/
npm run preview   # serve the built PWA (test install / offline)
```

## Cloud sync (optional)

Local-only by default. To sync with the [Orbit API](../backend):

```bash
cp .env.example .env.local     # sets VITE_API_BASE_URL=http://localhost:8000
```

On launch the store hydrates from the backend; if the backend is empty it pushes
the local set up; every add/edit/delete writes through. If the backend is
unreachable the app keeps working from the local cache and Settings shows the
sync status.

## Install to Home Screen

Open the previewed/hosted build on a phone → Share → **Add to Home Screen**.
It launches full-screen with no browser chrome (standalone PWA, offline-capable).
