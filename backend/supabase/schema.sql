-- Revolution — Supabase schema
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor → New query → Run).
--
-- One table holds every renewal reminder across all categories.
-- The category ("identity_government") and item key ("driving_license") are
-- stored as plain text so we can add new categories/items without migrations.

create extension if not exists "pgcrypto";

create table if not exists public.reminders (
    id              uuid primary key default gen_random_uuid(),

    -- Ownership. For now a device/user string; swap to auth.uid() once auth is added.
    owner_id        text not null,

    -- What this reminder is about.
    category        text not null,          -- e.g. 'identity_government'
    item_key        text not null,          -- e.g. 'driving_license'
    title           text not null,          -- user-facing label, prefilled but editable

    -- The document identifier (license no., passport no.) — optional, kept as text.
    document_number text,

    -- Dates. issue_date + validity drive expiry; remind_on is when to nudge.
    issue_date      date,
    expiry_date     date not null,
    remind_on       date not null,

    -- How many days before expiry we remind (kept so the UI can show/edit it).
    remind_days_before integer not null default 60,

    -- Free-form extras (issuing authority, state, holder name, notes…).
    metadata        jsonb not null default '{}'::jsonb,

    is_active       boolean not null default true,

    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

create index if not exists reminders_owner_idx    on public.reminders (owner_id);
create index if not exists reminders_remind_idx   on public.reminders (remind_on);
create index if not exists reminders_category_idx on public.reminders (category);

-- Keep updated_at fresh on every write.
create or replace function public.set_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

drop trigger if exists reminders_set_updated_at on public.reminders;
create trigger reminders_set_updated_at
    before update on public.reminders
    for each row execute function public.set_updated_at();

-- NOTE ON SECURITY:
-- The FastAPI backend is the ONLY writer and it uses the Supabase SERVICE ROLE key,
-- which bypasses Row Level Security. We therefore keep RLS enabled with no public
-- policies, so nothing can reach this table except the backend. Do not expose the
-- service role key to the Flutter app.
alter table public.reminders enable row level security;


-- ---------------------------------------------------------------------------
-- Phone verification (onboarding)
--
-- We verify a user's phone number for FREE via WhatsApp: the app shows a code,
-- the USER sends it to our WhatsApp number, and Meta's inbound webhook tells us
-- which number sent which code. User-initiated messages are free, so there is
-- no SMS cost, no India DLT, and no billing card.
--
-- One row per verification attempt. The code is stored HASHED (never plaintext).
-- The row is 'pending' until the matching inbound WhatsApp message arrives, then
-- it flips to 'verified'. Rows expire so a stale code can't be reused.
-- ---------------------------------------------------------------------------
create table if not exists public.phone_verifications (
    id              uuid primary key default gen_random_uuid(),

    -- Ownership. Same device/user string used elsewhere (X-Owner-Id header).
    owner_id        text not null,

    -- The number being verified, stored in E.164 (e.g. '+919876543210').
    phone           text not null,

    -- SHA-256 of the short code the user must send us over WhatsApp. Never plaintext.
    code_hash       text not null,

    -- Lifecycle: 'pending' → 'verified' (or left to expire).
    status          text not null default 'pending',

    -- Abuse guard: how many wrong inbound codes we've seen for this attempt.
    attempts        integer not null default 0,

    expires_at      timestamptz not null,
    verified_at     timestamptz,

    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- One quick lookup by the code when a webhook arrives, and by owner for status.
create index if not exists phone_verif_owner_idx  on public.phone_verifications (owner_id);
create index if not exists phone_verif_phone_idx  on public.phone_verifications (phone);
create index if not exists phone_verif_status_idx on public.phone_verifications (status);

drop trigger if exists phone_verif_set_updated_at on public.phone_verifications;
create trigger phone_verif_set_updated_at
    before update on public.phone_verifications
    for each row execute function public.set_updated_at();

-- Same security posture as reminders: backend-only writer, RLS on, no public policy.
alter table public.phone_verifications enable row level security;
