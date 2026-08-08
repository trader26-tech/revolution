-- ============================================================================
-- Revolution — schema v2 (clean slate)
-- Paste the WHOLE file into Supabase → SQL Editor → Run. Safe to re-run.
--
-- Design
-- ──────
-- Anonymous-first accounts:
--   1. On install the app calls POST /users/anonymous; the DATABASE mints the
--      account uuid (the primary key) and returns it. The app stores it and
--      sends it as X-User-Id on every request. Every onboarding task saves
--      against it immediately — no login wall.
--   2. On phone login the backend calls claim_user(anon_id, phone):
--        • phone never seen before → the SAME row is claimed (phone filled in,
--          status → 'claimed'). Tasks already point at it. Zero copying.
--        • phone already has an account (re-install / second device) → the
--          anonymous user's tasks/history/reminders are re-pointed onto that
--          account atomically, the empty shell is deleted, and the existing
--          account id is returned. The app switches to that id.
--
-- Three core tables + one auxiliary:
--   users             who (anonymous or claimed) + notification prefs
--   tasks             what to remember (the schedule is the source of truth)
--   task_completions  history — one row per occurrence marked done/paid
--   reminders         auxiliary outbound-notification queue
--
-- Speed: every hot path is one single-index lookup —
--   home screen        tasks(user_id) WHERE NOT archived
--   calendar           tasks(user_id, due_at)
--   weekly digest      users(call_reminder) + tasks(due_at range)
--   notifier cron      reminders(remind_at) WHERE pending
--
-- Security: the FastAPI backend is the ONLY writer (service-role key). RLS is
-- ON with no public policies, so nothing else can touch these tables.
-- ============================================================================

-- ── 0. Clean slate ──────────────────────────────────────────────────────────
-- Drops every table from the earlier experiments. THIS DELETES THEIR DATA.
drop table if exists public.reminders           cascade;
drop table if exists public.task_completions    cascade;
drop table if exists public.tasks               cascade;
drop table if exists public.phone_verifications cascade;
drop table if exists public.family_members      cascade;
drop table if exists public.user_prefs          cascade;
drop table if exists public.prefs               cascade;
drop table if exists public.users               cascade;
drop function if exists public.claim_user(uuid, text, text);

create extension if not exists pgcrypto;

-- Shared updated_at maintenance.
create or replace function public.set_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

-- ── 1. users ────────────────────────────────────────────────────────────────
-- One row per person. Born anonymous (phone NULL); claimed on login. Also
-- carries the notification preferences, so there is no separate prefs table.
create table public.users (
    -- Minted BY THE DATABASE (POST /users/anonymous returns it to the app) —
    -- the server owns its primary keys.
    id            uuid primary key default gen_random_uuid(),

    -- E.164 ('+919876543210'). NULL while anonymous. UNIQUE: one account per
    -- number (Postgres allows many NULLs, so anonymous rows never collide).
    phone         text unique,

    display_name  text,

    -- For a future password/PIN. Store a HASH only — never plaintext.
    password_hash text,

    status        text not null default 'anonymous'
                  check (status in ('anonymous', 'claimed')),

    -- Notification prefs (the weekly "call me to remind" digest reads these).
    call_reminder boolean not null default true,

    -- Product telemetry: when onboarding finished, when last active.
    onboarded_at  timestamptz,
    last_seen_at  timestamptz not null default now(),

    created_at    timestamptz not null default now(),
    updated_at    timestamptz not null default now(),

    -- A claimed account must actually have a phone.
    check (status = 'anonymous' or phone is not null)
);

create trigger users_set_updated_at
    before update on public.users
    for each row execute function public.set_updated_at();

alter table public.users enable row level security;

-- ── 2. tasks ────────────────────────────────────────────────────────────────
-- Everything the user tracks: subscriptions, bills, documents, birthdays.
-- The row IS the schedule (what + when + how often). What happened each cycle
-- lives in task_completions, so history never bloats or rewrites this table.
create table public.tasks (
    id           uuid primary key default gen_random_uuid(),
    user_id      uuid not null references public.users (id) on delete cascade,

    title        text not null,
    notes        text,

    -- Life category, matching the app's sections:
    -- 'subscription' | 'bill' | 'document' | 'family' | 'insurance'
    -- | 'investment' | 'other'
    category     text not null default 'other',

    -- Brand logo: domain drives the real logo, name seeds the letter fallback.
    icon_name    text,
    icon_domain  text,

    amount       numeric(14, 2),          -- NULL = no cost attached
    currency     text not null default 'INR',

    -- Next due moment. For repeating tasks the backend advances it each time
    -- an occurrence completes. NULL = unscheduled ("set a date later").
    due_at       timestamptz,

    repeat       text not null default 'none'
                 check (repeat in ('none', 'daily', 'weekly', 'monthly', 'yearly')),

    reminder_on  boolean not null default true,

    -- One-off lifecycle. Repeating tasks stay done=false; their per-cycle
    -- completions are rows in task_completions.
    done         boolean not null default false,

    -- Soft delete — keeps history intact and undo instant.
    archived     boolean not null default false,

    -- Where it came from, e.g. the onboarding chip key ('subs_netflix').
    source       text,

    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);

-- THE hot query: "give me this user's live tasks" — one partial-index scan.
create index tasks_user_live_idx  on public.tasks (user_id) where not archived;
-- Calendar / agenda ordering, and the weekly-digest date-range scan.
create index tasks_user_due_idx   on public.tasks (user_id, due_at);
create index tasks_due_idx        on public.tasks (due_at) where not archived;

create trigger tasks_set_updated_at
    before update on public.tasks
    for each row execute function public.set_updated_at();

alter table public.tasks enable row level security;

-- ── 3. task_completions ─────────────────────────────────────────────────────
-- One row every time an occurrence is marked done/paid. Powers streaks,
-- "you spent ₹X this year", and undo — without ever rewriting `tasks`.
create table public.task_completions (
    id            uuid primary key default gen_random_uuid(),
    task_id       uuid not null references public.tasks (id) on delete cascade,

    -- Denormalised on purpose: per-user history reads skip the join.
    user_id       uuid not null references public.users (id) on delete cascade,

    -- Which occurrence this was (its scheduled date) — one completion per
    -- occurrence, so double-taps can't double-count.
    due_on        date not null,
    completed_at  timestamptz not null default now(),

    amount_paid   numeric(14, 2),

    unique (task_id, due_on)
);

create index completions_user_idx
    on public.task_completions (user_id, completed_at desc);

alter table public.task_completions enable row level security;

-- ── 4. reminders (auxiliary) ────────────────────────────────────────────────
-- The outbound nudge queue. A cron/worker asks one question — "what's pending
-- and due?" — sends it, marks it sent. Regenerated freely from `tasks`.
create table public.reminders (
    id          uuid primary key default gen_random_uuid(),
    task_id     uuid not null references public.tasks (id) on delete cascade,
    user_id     uuid not null references public.users (id) on delete cascade,

    remind_at   timestamptz not null,
    channel     text not null default 'push'
                check (channel in ('push', 'whatsapp', 'call', 'email')),
    status      text not null default 'pending'
                check (status in ('pending', 'sent', 'cancelled')),
    sent_at     timestamptz,

    created_at  timestamptz not null default now()
);

-- The worker's single query, kept tiny by the partial index.
create index reminders_pending_idx
    on public.reminders (remind_at) where status = 'pending';
create index reminders_task_idx on public.reminders (task_id);

alter table public.reminders enable row level security;

-- ── 5. The pairing: claim_user ──────────────────────────────────────────────
-- Called by the backend when an anonymous user logs in with a phone number.
-- Atomic: either claims the anonymous row, or merges it into the account that
-- already owns the number. Race-safe: a concurrent claim of the same phone
-- loses the unique-index race and falls through to the merge path. Returns the
-- id the app must use from then on.
create or replace function public.claim_user(
    p_anon_id      uuid,
    p_phone        text,
    p_display_name text default null
) returns uuid
language plpgsql
as $$
declare
    v_existing uuid;
begin
    -- The anonymous row may never have reached the server (offline install):
    -- make sure it exists before working with it.
    insert into public.users (id) values (p_anon_id)
    on conflict (id) do nothing;

    select id into v_existing from public.users where phone = p_phone;

    if v_existing is null or v_existing = p_anon_id then
        -- First login for this number: claim the anonymous row in place.
        begin
            update public.users
               set phone        = p_phone,
                   status       = 'claimed',
                   display_name = coalesce(nullif(trim(p_display_name), ''),
                                           display_name),
                   last_seen_at = now()
             where id = p_anon_id;
            return p_anon_id;
        exception when unique_violation then
            -- Lost a race: someone claimed this phone between our SELECT and
            -- UPDATE. Fall through to the merge path below.
            select id into v_existing from public.users where phone = p_phone;
        end;
    end if;

    -- The number already has an account (re-install / second device / race):
    -- move everything the anonymous user made onto it, drop the empty shell.
    update public.tasks            set user_id = v_existing where user_id = p_anon_id;
    update public.task_completions set user_id = v_existing where user_id = p_anon_id;
    update public.reminders        set user_id = v_existing where user_id = p_anon_id;
    delete from public.users where id = p_anon_id and status = 'anonymous';

    update public.users
       set last_seen_at = now(),
           display_name = coalesce(nullif(trim(p_display_name), ''), display_name)
     where id = v_existing;
    return v_existing;
end;
$$;
