-- Boards: public, user-curated collections of posts. Saved stays private (existing `saves` table).
create table if not exists public.boards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  created_at timestamptz not null default now()
);
create index if not exists boards_user_id_idx on public.boards(user_id);

create table if not exists public.board_posts (
  board_id uuid not null references public.boards(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  added_at timestamptz not null default now(),
  primary key (board_id, post_id)
);
create index if not exists board_posts_post_id_idx on public.board_posts(post_id);

alter table public.boards enable row level security;
alter table public.board_posts enable row level security;

create policy "boards readable" on public.boards for select using (true);
create policy "boards insert own" on public.boards for insert with check (user_id = (select auth.uid()));
create policy "boards update own" on public.boards for update using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "boards delete own" on public.boards for delete using (user_id = (select auth.uid()));

create policy "board_posts readable" on public.board_posts for select using (true);
create policy "board_posts insert own" on public.board_posts for insert
  with check (exists (select 1 from public.boards b where b.id = board_id and b.user_id = (select auth.uid())));
create policy "board_posts delete own" on public.board_posts for delete
  using (exists (select 1 from public.boards b where b.id = board_id and b.user_id = (select auth.uid())));

-- no following yourself
alter table public.follows add constraint follows_no_self check (follower <> followee);
