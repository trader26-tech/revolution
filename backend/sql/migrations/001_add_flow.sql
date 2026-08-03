-- Migration 001 — add the `flow` column (income vs expense).
--
-- Run this in the Supabase SQL editor if your `subscriptions` table was
-- created BEFORE income/expense support was added. Safe to run more than
-- once. New projects get the column from subscriptions.sql directly.

alter table public.subscriptions
  add column if not exists flow text not null default 'expense';

-- Constrain to the two valid directions (added separately so the statement
-- above stays idempotent).
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'subscriptions_flow_check'
  ) then
    alter table public.subscriptions
      add constraint subscriptions_flow_check
      check (flow in ('income', 'expense'));
  end if;
end $$;
