-- RLS policies: each user can only see their own rows
alter table public.categories enable row level security;
alter table public.transactions enable row level security;
alter table public.attachments enable row level security;

do $$ begin
  create policy "own categories"
    on public.categories
    for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "own transactions"
    on public.transactions
    for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "own attachments"
    on public.attachments
    for all
    using (exists (select 1 from public.transactions t where t.id = tx_id and t.user_id = auth.uid()))
    with check (exists (select 1 from public.transactions t where t.id = tx_id and t.user_id = auth.uid()));
exception when duplicate_object then null; end $$;
