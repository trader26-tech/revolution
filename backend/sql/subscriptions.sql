-- Orbit — subscriptions table
-- Run in the Supabase SQL editor (or via the CLI) to provision persistence.
-- Column names are snake_case to match the API schema
-- (backend/app/schemas/subscription.py).

create table if not exists public.subscriptions (
  id             text primary key,
  name           text        not null,
  color          text        not null default '#8a1cff',
  mark           text        not null default '○',
  amount         numeric      not null default 0 check (amount >= 0),
  currency       text        not null default 'USD',
  cycle          text        not null default 'monthly'
                   check (cycle in ('weekly', 'monthly', 'yearly')),
  category       text        not null default 'Other',
  "list"         text        not null default 'Personal'
                   check ("list" in ('Personal', 'Family', 'Business')),
  payment_method text        not null default '',
  anchor_date    date        not null,
  is_trial       boolean     not null default false,
  trial_ends     date,
  notes          text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index if not exists subscriptions_anchor_date_idx
  on public.subscriptions (anchor_date);

-- keep updated_at fresh on every write
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists subscriptions_set_updated_at on public.subscriptions;
create trigger subscriptions_set_updated_at
  before update on public.subscriptions
  for each row execute function public.set_updated_at();

-- Row Level Security.
-- The starter uses a single service key server-side, so RLS is left disabled.
-- For multi-tenant / per-user data, add a `user_id uuid` column, enable RLS,
-- and write policies scoped to auth.uid().
-- alter table public.subscriptions enable row level security;
