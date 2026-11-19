-- ============================================================================
-- 087_topup.sql
-- Keeps the bank ahead of him. For each exam he is preparing for, count the
-- questions he has not attempted; when that falls below 20, ask for 20 more,
-- written to his level in that exam's scope.
-- Run after 086. Safe to re-run.
-- ============================================================================

create table if not exists question_topups (
  id bigserial primary key,
  student_id uuid references auth.users(id) on delete cascade,
  exam text not null,
  asked_for int not null,
  made int default 0,
  reason text,
  at timestamptz default now()
);
alter table question_topups enable row level security;
drop policy if exists "own topups" on question_topups;
create policy "own topups" on question_topups for select to authenticated
  using (student_id = auth.uid() or is_guardian(student_id));

-- how many are left, per exam, and whether that is short
create or replace function unattempted_by_exam()
returns json
language sql security definer set search_path = public as $$
  with who as (select coalesce(viewing_student(), auth.uid()) as sid)
  select coalesce(json_agg(row_to_json(t) order by t.exam), '[]'::json)
  from (
    select b.exam,
           (select count(*) from problems p where p.source = b.kind) as in_bank,
           (select count(*) from problems p
             where p.source = b.kind
               and not exists (select 1 from attempts a
                                where a.student_id = who.sid and a.chapter = p.chapter and a.idx = p.idx)) as left_to_try
    from exam_banks b, who
    where b.family in ('aas','edutest','olympiad')     -- the three the coach writes for
  ) t;
$$;

grant execute on function unattempted_by_exam() to authenticated;

-- what to do about it: 20 more for any exam with fewer than 20 left
create or replace function topup_needed()
returns json
language sql security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object('exam', exam, 'left_to_try', left_to_try, 'want', 20)), '[]'::json)
  from json_to_recordset(unattempted_by_exam()) as x(exam text, in_bank int, left_to_try int)
  where left_to_try < 20;
$$;

grant execute on function topup_needed() to authenticated;

create or replace function log_topup(p_exam text, p_asked int, p_made int, p_reason text default null)
returns void
language sql security definer set search_path = public as $$
  insert into question_topups (student_id, exam, asked_for, made, reason)
  values (coalesce(viewing_student(), auth.uid()), p_exam, p_asked, p_made, p_reason);
$$;

grant execute on function log_topup(text, int, int, text) to authenticated;
