-- ============================================================================
-- Revolution — Documents (file library) schema
-- Paste the WHOLE file into Supabase → SQL Editor → Run. Safe to re-run.
--
-- Standalone documents: a first-class file the user adds directly in the
-- Documents tab (a name + a folder + the file), independent of any task. The
-- app merges these with task-attached policies for one unified library.
--
-- Design
-- ──────
--   documents      one row per uploaded file
--   user-docs      a PRIVATE storage bucket the file bytes live in; the app
--                  only ever gets short-lived signed URLs to view/share.
--
-- Identity reuses the anonymous account model: user_id is the public.users(id)
-- the app sends as X-User-Id, so a document is scoped to its owner.
--
-- Security: RLS is ON with NO public policies — only the FastAPI backend
-- (service-role key) reads/writes, exactly like the other tables.
-- ============================================================================

create extension if not exists "pgcrypto";

create table if not exists public.documents (
    id           uuid primary key default gen_random_uuid(),

    -- The owning account. Cascade-deletes with the user.
    user_id      uuid not null references public.users (id) on delete cascade,

    -- The user-given display name (e.g. "Zerodha statement").
    name         text not null check (char_length(name) between 1 and 200),

    -- The folder it lives in — one of the app's task categories:
    -- subscription | birthday | insurance | investment | bills | other.
    -- Kept as free text (not an enum) so new categories don't need a migration.
    folder       text not null default 'other',

    -- Object path inside the private `user-docs` bucket ("<user>/<id>.pdf").
    path         text not null default '',

    content_type text,
    size         bigint,

    created_at   timestamptz not null default now()
);

-- Hot path: list a user's documents, newest first (the Documents tab).
create index if not exists documents_user_idx
    on public.documents (user_id, created_at desc);

-- Group-by-folder reads.
create index if not exists documents_folder_idx
    on public.documents (user_id, folder);

alter table public.documents enable row level security;

-- ── Private storage bucket for the file bytes ───────────────────────────────
-- Idempotent: create the bucket only if it's missing. Private → the app must
-- use signed URLs (minted by the backend) to read anything.
insert into storage.buckets (id, name, public, file_size_limit)
values ('user-docs', 'user-docs', false, 10485760)  -- 10 MB
on conflict (id) do nothing;

-- No storage RLS policies: the backend uses the service-role key, which bypasses
-- RLS, and no client ever touches the bucket directly.

-- ============================================================================
-- Done. The backend (service-role) is the only reader/writer. Endpoint contract:
--   GET    /documents          → list
--   POST   /documents          → multipart {file, name, folder}
--   GET    /documents/{id}     → { url } (signed, ~1h)
--   DELETE /documents/{id}
-- App client: frontend/lib/features/documents/data/documents_api.dart
-- ============================================================================
