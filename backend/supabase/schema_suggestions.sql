-- ============================================================================
-- Revolution — Suggestions (Ideas board) schema
-- Paste the WHOLE file into Supabase → SQL Editor → Run. Safe to re-run.
--
-- The Ideas board: anonymous community suggestions the whole user base can
-- up/down-vote, with a status the creator advances (open → planned → done).
--
-- Design
-- ──────
--   suggestions        one row per idea (anonymous — author id kept only for
--                      "mine"/moderation, never shown to other users)
--   suggestion_votes   one row per (suggestion, user) — the vote value -1/+1;
--                      a 0/clear is represented by deleting the row
--
-- Score = sum(value) over the votes. We keep a cached `score` column on
-- suggestions (kept correct by a trigger) so the list sorts fast without a
-- GROUP BY on every read.
--
-- Identity reuses the existing anonymous account model: user_id is the same
-- public.users(id) the app already sends as X-User-Id. So votes are per-account
-- and can't be double-counted, while the idea text carries no author.
--
-- Security: RLS is ON with NO public policies — only the FastAPI backend
-- (service-role key) reads/writes, exactly like the other tables.
-- ============================================================================

create extension if not exists "pgcrypto";

-- ── suggestions ─────────────────────────────────────────────────────────────
create table if not exists public.suggestions (
    id          uuid primary key default gen_random_uuid(),

    -- The anonymous author's account. Never exposed to other users; used only
    -- to flag "mine" for that account and for moderation. Nullable so an idea
    -- survives if its author's account is deleted.
    author_id   uuid references public.users (id) on delete set null,

    text        text not null check (char_length(text) between 1 and 280),

    -- Lifecycle the CREATOR advances from the DB / admin:
    --   'open'    — under consideration (default)
    --   'planned' — accepted, on the roadmap
    --   'done'    — shipped (triggers the Revo celebration in-app)
    status      text not null default 'open'
                     check (status in ('open', 'planned', 'done')),

    -- Cached score = sum of vote values (kept correct by the trigger below).
    score       integer not null default 0,

    -- Hide spam/abuse without deleting (filtered out by the API).
    is_hidden   boolean not null default false,

    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    -- When the creator marked it done — handy for "recently shipped" ordering.
    shipped_at  timestamptz
);

-- Hot path: list visible ideas, most-popular first.
create index if not exists suggestions_rank_idx
    on public.suggestions (score desc, created_at desc)
    where not is_hidden;

create index if not exists suggestions_status_idx
    on public.suggestions (status)
    where not is_hidden;

alter table public.suggestions enable row level security;

-- ── suggestion_votes ────────────────────────────────────────────────────────
create table if not exists public.suggestion_votes (
    suggestion_id uuid not null references public.suggestions (id) on delete cascade,
    user_id       uuid not null references public.users (id)       on delete cascade,

    -- -1 (down) or +1 (up). Clearing a vote = deleting the row.
    value         smallint not null check (value in (-1, 1)),

    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),

    -- One vote per account per idea.
    primary key (suggestion_id, user_id)
);

create index if not exists suggestion_votes_user_idx
    on public.suggestion_votes (user_id);

alter table public.suggestion_votes enable row level security;

-- ── Keep suggestions.score in sync with the votes ───────────────────────────
create or replace function public.suggestions_apply_vote_delta()
returns trigger
language plpgsql
as $$
begin
    if (tg_op = 'INSERT') then
        update public.suggestions
           set score = score + new.value, updated_at = now()
         where id = new.suggestion_id;
        return new;
    elsif (tg_op = 'UPDATE') then
        update public.suggestions
           set score = score + (new.value - old.value), updated_at = now()
         where id = new.suggestion_id;
        return new;
    elsif (tg_op = 'DELETE') then
        update public.suggestions
           set score = score - old.value, updated_at = now()
         where id = old.suggestion_id;
        return old;
    end if;
    return null;
end;
$$;

drop trigger if exists suggestion_votes_score_trg on public.suggestion_votes;
create trigger suggestion_votes_score_trg
    after insert or update or delete on public.suggestion_votes
    for each row execute function public.suggestions_apply_vote_delta();

-- Stamp shipped_at when status flips to 'done'.
create or replace function public.suggestions_touch_shipped()
returns trigger
language plpgsql
as $$
begin
    if (new.status = 'done' and coalesce(old.status, '') <> 'done') then
        new.shipped_at := now();
    end if;
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists suggestions_touch_shipped_trg on public.suggestions;
create trigger suggestions_touch_shipped_trg
    before update on public.suggestions
    for each row execute function public.suggestions_touch_shipped();

-- ============================================================================
-- Done. The backend (service-role) is the only reader/writer. See the endpoint
-- contract in the app: frontend/lib/features/suggestions/data/suggestions_api.dart
-- ============================================================================
