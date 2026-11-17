-- 001_schema.sql — the schema as it stands in the project today (verbatim).
-- Used only to test the upgrade against the real starting point.

create table if not exists chapters (
  n int primary key, title text not null, pages text,
  examples int default 0, practice int default 0
);

create table if not exists problems (
  chapter int not null references chapters(n) on delete cascade,
  idx int not null, prompt text not null, answer text not null,
  primary key (chapter, idx)
);

create table if not exists profiles (
  student_id uuid primary key references auth.users(id) on delete cascade,
  name text default '',
  start_date date default current_date,
  target_date date default date '2027-01-15',
  days_per_week int default 5,
  session_min int default 30,
  xp int default 0,
  created_at timestamptz default now()
);

create table if not exists attempts (
  student_id uuid not null references auth.users(id) on delete cascade,
  chapter int not null, idx int not null,
  ok boolean not null default false,
  hints int default 0, working boolean default false,
  xp int default 0, mode text default 'quest',
  updated_at timestamptz default now(),
  primary key (student_id, chapter, idx)
);

create table if not exists reviews (
  student_id uuid not null references auth.users(id) on delete cascade,
  chapter int not null, idx int not null,
  misses int default 0, next_review date, technique text,
  primary key (student_id, chapter, idx)
);

create table if not exists chapter_meta (
  student_id uuid not null references auth.users(id) on delete cascade,
  chapter int not null,
  examples_reviewed boolean default false,
  quiz_best int default 0,
  weak boolean default false,
  primary key (student_id, chapter)
);

create table if not exists badges (
  student_id uuid not null references auth.users(id) on delete cascade,
  key text not null, earned_at timestamptz default now(),
  primary key (student_id, key)
);

create table if not exists exams (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references auth.users(id) on delete cascade,
  kind text not null,
  scope text,
  score int default 0, total int default 0, pct int default 0,
  minutes int default 0, passed boolean default false,
  taken_at timestamptz default now()
);

alter table chapters     enable row level security;
alter table problems     enable row level security;
alter table profiles     enable row level security;
alter table attempts     enable row level security;
alter table reviews      enable row level security;
alter table chapter_meta enable row level security;
alter table badges       enable row level security;
alter table exams        enable row level security;

drop policy if exists "read chapters" on chapters;
create policy "read chapters" on chapters for select to authenticated using (true);
drop policy if exists "read problems" on problems;
create policy "read problems" on problems for select to authenticated using (true);

do $$
declare t text;
begin
  foreach t in array array['profiles','attempts','reviews','chapter_meta','badges','exams'] loop
    execute format('drop policy if exists "own rows" on %I', t);
    execute format('create policy "own rows" on %I for all to authenticated using (student_id = auth.uid()) with check (student_id = auth.uid())', t);
  end loop;
end $$;

create table if not exists share_links (
  token text primary key,
  student_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now()
);
alter table share_links enable row level security;
drop policy if exists "own shares" on share_links;
create policy "own shares" on share_links for all to authenticated
  using (student_id = auth.uid()) with check (student_id = auth.uid());

create or replace function read_share(p_token text)
returns json language sql security definer set search_path = public as $$
  select json_build_object(
    'profile', (select to_json(p) from profiles p where p.student_id = sl.student_id),
    'attempts', coalesce((select json_agg(json_build_object('chapter',chapter,'idx',idx,'ok',ok)) from attempts where student_id = sl.student_id),'[]'::json),
    'badges', coalesce((select json_agg(key) from badges where student_id = sl.student_id),'[]'::json),
    'exams', coalesce((select json_agg(json_build_object('kind',kind,'pct',pct,'taken_at',taken_at)) from exams where student_id = sl.student_id),'[]'::json)
  ) from share_links sl where sl.token = p_token;
$$;
grant execute on function read_share(text) to anon, authenticated;
