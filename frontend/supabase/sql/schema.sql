-- Supabase PostgreSQL schema for Income–Expense app
-- Enable pgcrypto for gen_random_uuid()
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  currency text default 'KZT',
  created_at timestamptz default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  type text check (type in ('income','expense')) not null,
  created_at timestamptz default now()
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category_id uuid references public.categories(id),
  type text check (type in ('income','expense')) not null,
  amount numeric(14,2) not null,
  note text,
  payment_method text,
  is_recurring boolean default false,
  reminder_at timestamptz,
  occurred_at date not null,
  created_at timestamptz default now()
);

create table if not exists public.attachments (
  id uuid primary key default gen_random_uuid(),
  tx_id uuid not null references public.transactions(id) on delete cascade,
  file_path text not null,
  created_at timestamptz default now()
);
