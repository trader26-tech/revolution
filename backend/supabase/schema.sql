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
