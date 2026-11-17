-- ============================================================================
-- 023_solo.sql
-- When he works in the app on his own — opens a chapter, practises one, takes a
-- quiz without the coach — the coach should still know about it next time.
-- Run after 022. Safe to re-run.
-- ============================================================================

create table if not exists chapter_visits (
  id bigserial primary key,
  student_id uuid not null references auth.users(id) on delete cascade,
  chapter int not null,
  source text default 'book',        -- book | solo-practice | coach
  at timestamptz default now()
);
alter table chapter_visits enable row level security;
drop policy if exists "own rows" on chapter_visits;
create policy "own rows" on chapter_visits for all to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
drop policy if exists "guardian read" on chapter_visits;
create policy "guardian read" on chapter_visits for select to authenticated using (is_guardian(student_id));

create index if not exists chapter_visits_recent on chapter_visits(student_id, at desc);

create or replace function log_visit(p_chapter int, p_source text default 'book')
returns void
language sql security definer set search_path = public as $$
  insert into chapter_visits (student_id, chapter, source)
  values (auth.uid(), p_chapter, coalesce(p_source,'book'));
$$;

-- ---- the coach also sees what he did alone -------------------------------
create or replace function solo_activity()
returns json
language sql security definer set search_path = public as $$
  select json_build_object(
    'chapters_opened', coalesce((select json_agg(json_build_object('chapter',chapter,'source',source,'at',at) order by at desc)
                       from (select * from chapter_visits where student_id = auth.uid() order by at desc limit 8) t), '[]'::json),
    'solo_attempts_7d', (select count(*) from attempts
                          where student_id = auth.uid() and mode = 'solo' and created_at > now() - interval '7 days'),
    'solo_accuracy_7d', coalesce((select round(100.0 * count(*) filter (where ok) / greatest(count(*),1))
                          from attempts where student_id = auth.uid() and mode = 'solo'
                            and created_at > now() - interval '7 days'), 0),
    'solo_chapters_7d', coalesce((select json_agg(distinct chapter)
                          from attempts where student_id = auth.uid() and mode = 'solo'
                            and created_at > now() - interval '7 days'), '[]'::json),
    'tests_alone', coalesce((select json_agg(json_build_object('kind',kind,'pct',pct,'taken_at',taken_at) order by taken_at desc)
                       from (select * from exam_mocks where student_id = auth.uid() order by taken_at desc limit 3) t), '[]'::json)
  );
$$;
