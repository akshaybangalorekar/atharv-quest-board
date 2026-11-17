-- ============================================================================
-- 029_notes.sql
-- The journal: one note per finished session, so he can go back to it.
-- And the formula board: what should be written on the physical board.
-- Run after 028. Safe to re-run.
-- ============================================================================

create table if not exists session_notes (
  id bigserial primary key,
  student_id uuid not null references auth.users(id) on delete cascade,
  day date not null default current_date,
  title text not null,
  body text not null,
  chapter int,
  minutes int default 0,
  questions int default 0,
  created_at timestamptz default now()
);
alter table session_notes enable row level security;
drop policy if exists "own rows" on session_notes;
create policy "own rows" on session_notes for all to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
drop policy if exists "guardian read" on session_notes;
create policy "guardian read" on session_notes for select to authenticated using (is_guardian(student_id));
create index if not exists session_notes_recent on session_notes(student_id, day desc);

create table if not exists formula_board (
  student_id uuid not null references auth.users(id) on delete cascade,
  chapter int not null,
  technique text not null,
  added_at timestamptz default now(),
  primary key (student_id, chapter, technique)
);
alter table formula_board enable row level security;
drop policy if exists "own rows" on formula_board;
create policy "own rows" on formula_board for all to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
drop policy if exists "guardian read" on formula_board;
create policy "guardian read" on formula_board for select to authenticated using (is_guardian(student_id));

-- what he should have on the board, chapter by chapter, and what is already there
create or replace function formula_board_view()
returns json
language sql security definer set search_path = public as $$
  select coalesce(json_agg(row_to_json(t) order by t.chapter, t.technique), '[]'::json)
  from (
    select c.n as chapter, c.title as chapter_title,
           trim(both '"' from idea::text) as technique,
           exists (select 1 from formula_board f
                   where f.student_id = auth.uid() and f.chapter = c.n
                     and f.technique = trim(both '"' from idea::text)) as on_board,
           exists (select 1 from attempts a where a.student_id = auth.uid() and a.chapter = c.n) as touched
    from chapters c
    join chapter_notes n on n.chapter = c.n
    cross join lateral jsonb_array_elements(n.ideas) idea
    where c.n between 1 and 24
  ) t;
$$;
