-- 1:1 direct messages. user_a < user_b keeps one row per pair.
create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles(id) on delete cascade,
  user_b uuid not null references public.profiles(id) on delete cascade,
  last_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  check (user_a < user_b),
  unique (user_a, user_b)
);
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conv_id uuid not null references public.conversations(id) on delete cascade,
  sender uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index messages_conv_idx on public.messages (conv_id, created_at desc);
create index conversations_a_idx on public.conversations (user_a);
create index conversations_b_idx on public.conversations (user_b);

alter table public.conversations enable row level security;
alter table public.messages enable row level security;

create policy "conversations read own" on public.conversations for select
  using ((select auth.uid()) in (user_a, user_b));

create policy "messages read own" on public.messages for select
  using (exists (select 1 from public.conversations c where c.id = conv_id and (select auth.uid()) in (c.user_a, c.user_b)));
create policy "messages send own" on public.messages for insert
  with check (sender = (select auth.uid()) and exists (select 1 from public.conversations c where c.id = conv_id and (select auth.uid()) in (c.user_a, c.user_b)));
-- only the recipient may mark a message read
create policy "messages mark read" on public.messages for update
  using (sender <> (select auth.uid()) and exists (select 1 from public.conversations c where c.id = conv_id and (select auth.uid()) in (c.user_a, c.user_b)))
  with check (sender <> (select auth.uid()));
create policy "messages delete own" on public.messages for delete
  using (sender = (select auth.uid()));

-- start or fetch the conversation with another user
create or replace function public.start_dm(other uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); a uuid; b uuid; cid uuid;
begin
  if me is null then raise exception 'Sign in to send messages'; end if;
  if other is null or other = me then raise exception 'Pick someone else'; end if;
  if not exists (select 1 from public.profiles where id = other) then raise exception 'No such user'; end if;
  a := least(me, other); b := greatest(me, other);
  insert into public.conversations (user_a, user_b) values (a, b) on conflict (user_a, user_b) do nothing;
  select id into cid from public.conversations where user_a = a and user_b = b;
  return cid;
end $$;
revoke execute on function public.start_dm(uuid) from public, anon;
grant execute on function public.start_dm(uuid) to authenticated;

-- keep the inbox sorted
create or replace function public.touch_conversation() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.conversations set last_at = new.created_at where id = new.conv_id;
  return new;
end $$;
revoke execute on function public.touch_conversation() from public, anon, authenticated;
create trigger messages_touch after insert on public.messages for each row execute function public.touch_conversation();

alter publication supabase_realtime add table public.messages;
