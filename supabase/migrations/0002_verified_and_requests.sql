-- Verified creator badge: only the project owner flips it (Table Editor / service role).
alter table public.profiles add column if not exists verified boolean not null default false;

create or replace function public.protect_verified() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.verified := false;
  elsif new.verified is distinct from old.verified
        and coalesce(auth.role(), '') <> 'service_role'
        and current_user in ('authenticated', 'anon') then
    raise exception 'verified can only be changed by the project owner';
  end if;
  return new;
end $$;

drop trigger if exists protect_verified on public.profiles;
create trigger protect_verified before insert or update on public.profiles
  for each row execute function public.protect_verified();

create table if not exists public.verification_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  links text[] not null default '{}',
  note text check (char_length(note) <= 1000),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now()
);
alter table public.verification_requests enable row level security;
create policy "own requests read" on public.verification_requests for select using (auth.uid() = user_id);
create policy "own requests insert" on public.verification_requests for insert
  with check (auth.uid() = user_id and status = 'pending');
