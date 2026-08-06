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


-- ---------------------------------------------------------------------------
-- Users (multi-user accounts, phone-number login)
--
-- The phone number IS the identity. Logging in = find-or-create a row by phone;
-- the returned `id` becomes the X-Owner-Id the client sends on every request,
-- so each user only ever sees their own reminders.
--
-- No password / OTP yet — verification is a later step. `phone` is unique, so
-- the same number always resolves to the same account (the "link to existing
-- account" behaviour) instead of creating duplicates.
-- ---------------------------------------------------------------------------
create table if not exists public.users (
    id          uuid primary key default gen_random_uuid(),

    -- E.164, e.g. '+919876543210'. Unique — one account per number.
    phone       text not null unique,

    -- Optional profile fields, filled in later.
    display_name text,

    last_login_at timestamptz,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);

create unique index if not exists users_phone_idx on public.users (phone);

drop trigger if exists users_set_updated_at on public.users;
create trigger users_set_updated_at
    before update on public.users
    for each row execute function public.set_updated_at();

-- Backend-only writer, RLS on, no public policy — same as the rest.
alter table public.users enable row level security;


-- ---------------------------------------------------------------------------
-- Family members
--
-- The account holder (a `users` row) is the HEAD OF THE FAMILY. Every family
-- member — including the head themselves — is a `family_members` row owned by
-- that account. Reminders (insurance, passport, EMIs…) then link to a member,
-- so the head sees the whole chain: whose policy, whose licence, whose EMI.
--
-- `owner_id` matches the X-Owner-Id header (the head's users.id). `is_self`
-- marks the head's own "You" member, auto-created on first use. `relation`
-- is free text ('Self', 'Spouse', 'Son', 'Daughter', 'Father', 'Mother'…).
-- ---------------------------------------------------------------------------
create table if not exists public.family_members (
    id          uuid primary key default gen_random_uuid(),

    -- The head-of-family account this member belongs to (X-Owner-Id).
    owner_id    text not null,

    name        text not null,
    relation    text not null default 'Self',

    -- True for the head's own record; there is at most one per owner.
    is_self     boolean not null default false,

    -- Optional profile extras (dob, colour, notes…). Free-form.
    metadata    jsonb not null default '{}'::jsonb,

    is_active   boolean not null default true,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

create index if not exists family_members_owner_idx on public.family_members (owner_id);

-- One "self" member per owner (partial unique index).
create unique index if not exists family_members_one_self_idx
    on public.family_members (owner_id)
    where is_self;

drop trigger if exists family_members_set_updated_at on public.family_members;
create trigger family_members_set_updated_at
    before update on public.family_members
    for each row execute function public.set_updated_at();

alter table public.family_members enable row level security;


-- ---------------------------------------------------------------------------
-- Link every reminder to a family member.
--
-- Added as a nullable column so existing rows are untouched; new reminders
-- carry the member they belong to. ON DELETE SET NULL keeps a reminder alive
-- if its member is hard-deleted (we soft-delete members anyway).
-- ---------------------------------------------------------------------------
alter table public.reminders
    add column if not exists member_id uuid
    references public.family_members (id) on delete set null;

create index if not exists reminders_member_idx on public.reminders (member_id);


-- ---------------------------------------------------------------------------
-- Item details (rich subscription/renewal fields)
--
-- The extra fields a tracked item can carry beyond a plain name + date:
-- amount, billing cycle, list, category, payment method, notification, etc.
-- Mirrors the Flutter `ItemDetails` model. `owner_id` = X-Owner-Id (the user);
-- `task_id` optionally links back to the task/reminder this detail belongs to.
-- ---------------------------------------------------------------------------
create table if not exists public.item_details (
    id              uuid primary key default gen_random_uuid(),

    owner_id        text not null,
    task_id         text,

    -- Name + amount.
    name            text not null default '',
    amount          numeric(14,2),
    currency        text not null default '₹',

    -- Billing.
    first_payment_date date not null default (now()::date),
    -- 'recurring' | 'one_time'
    type            text not null default 'recurring',
    -- 'weekly' | 'monthly' | 'quarterly' | 'half_yearly' | 'yearly'
    cycle           text not null default 'monthly',
    duration_forever boolean not null default true,
    free_trial      boolean not null default false,

    -- Organization.
    list            text not null default 'Personal',
    category        text not null default 'Other',
    payment_method  text,

    -- Reminder lead time:
    -- 'none' | 'same_day' | 'one_day' | 'three_days' | 'one_week'
    notify          text not null default 'one_day',

    -- Extras.
    url             text not null default '',
    notes           text not null default '',

    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

create index if not exists item_details_owner_idx on public.item_details (owner_id);
create index if not exists item_details_task_idx  on public.item_details (task_id);

drop trigger if exists item_details_set_updated_at on public.item_details;
create trigger item_details_set_updated_at
    before update on public.item_details
    for each row execute function public.set_updated_at();

-- Backend-only writer, RLS on, no public policy — same posture as the rest.
alter table public.item_details enable row level security;


-- ---------------------------------------------------------------------------
-- Tasks (the items a user tracks on the home list)
--
-- Server is the ONLY store — the app reads/writes these via the backend, so a
-- user's list lives entirely in Supabase (nothing persisted on the device).
-- `owner_id` = the X-Owner-Id header (the logged-in user's id).
-- ---------------------------------------------------------------------------
create table if not exists public.tasks (
    id           uuid primary key default gen_random_uuid(),

    owner_id     text not null,

    title        text not null default '',
    done         boolean not null default false,
    reminder_on  boolean not null default true,
    due_at       timestamptz,
    -- 'none' | 'daily' | 'weekly' | 'monthly' | 'yearly'
    repeat       text not null default 'none',

    -- Optional brand/app icon.
    icon_name    text,
    icon_domain  text,

    -- Optional cost: the recurring/one-time amount and its currency (ISO code).
    -- null amount = no price (a free plan or a plain reminder).
    amount       numeric(14,2),
    currency     text not null default 'INR',

    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);

-- Migration for databases created before amount/currency existed. Safe to
-- re-run: IF NOT EXISTS makes each ALTER a no-op once applied.
alter table public.tasks add column if not exists amount   numeric(14,2);
alter table public.tasks add column if not exists currency text not null default 'INR';

create index if not exists tasks_owner_idx on public.tasks (owner_id);
create index if not exists tasks_due_idx   on public.tasks (due_at);

drop trigger if exists tasks_set_updated_at on public.tasks;
create trigger tasks_set_updated_at
    before update on public.tasks
    for each row execute function public.set_updated_at();

-- Backend-only writer, RLS on, no public policy — same posture as the rest.
alter table public.tasks enable row level security;


-- ---------------------------------------------------------------------------
-- Brand logos (manually-curated, for apps the auto-resolver can't find)
--
-- You upload a logo image to the `brand-logos` storage bucket and add a row
-- here. The app matches the user's typed text against `name` + `keywords` and,
-- on a hit, shows YOUR logo (guaranteed correct) instead of guessing a domain.
-- `keywords` is a space/comma list you provide for fuzzy matching.
-- ---------------------------------------------------------------------------
create table if not exists public.brand_logos (
    id         uuid primary key default gen_random_uuid(),

    name       text not null,            -- display name, e.g. 'Swiggy'
    category   text not null default 'Other', -- e.g. 'Banking & Finance'
    keywords   text not null default '', -- match text, e.g. 'swiggy food delivery'
    logo_url   text not null,            -- public URL in the brand-logos bucket

    -- Source of the row: 'seed' (pre-uploaded), 'admin' (you added), or
    -- 'user' (auto-saved when a user picked an icon we didn't already have).
    source     text not null default 'admin',

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists brand_logos_name_idx on public.brand_logos (lower(name));

drop trigger if exists brand_logos_set_updated_at on public.brand_logos;
create trigger brand_logos_set_updated_at
    before update on public.brand_logos
    for each row execute function public.set_updated_at();

-- Read is fine for anyone (logos aren't secret); writes go through the backend
-- service role. Enable RLS + a public read policy.
alter table public.brand_logos enable row level security;

drop policy if exists brand_logos_public_read on public.brand_logos;
create policy brand_logos_public_read
    on public.brand_logos for select
    using (true);
