-- ============================================================================
-- 028_dashboard.sql
-- One call that answers: how far through the plan are we, how well is it going,
-- and is he ahead or behind. Numbers only; the app draws the pictures.
-- Run after 027. Safe to re-run.
-- ============================================================================

create or replace function progress_dashboard()
returns json
language plpgsql security definer set search_path = public as $$
declare
  v uuid := viewing_student();
  v_today date := (now() at time zone 'Australia/Melbourne')::date;
  v_out json;
begin
  if v is null then raise exception 'no student' using errcode = '28000'; end if;
  if not (v = auth.uid() or is_guardian(v)) then
    raise exception 'not your child' using errcode = '42501';
  end if;

  select json_build_object(
    'today', v_today,
    'name', (select name from profiles where student_id = v),
    'days_in', (v_today - coalesce((select start_date from profiles where student_id = v), v_today)) + 1,
    'xp', coalesce((select xp from profiles where student_id = v),0),
    'streak', coalesce((select streak_days from profiles where student_id = v),0),

    -- the plan, up to today
    'planned_questions', coalesce((select sum(target_questions) from plan_days
                                   where student_id = v and day <= v_today and lane = 'Q'),0),
    'done_questions', (select count(*) from attempts where student_id = v),
    'accuracy', coalesce((select round(100.0*count(*) filter (where ok)/greatest(count(*),1))
                          from attempts where student_id = v),0),
    'avg_seconds', coalesce((select round(avg(seconds)) from attempts
                             where student_id = v and seconds is not null),0),

    -- chapters of the book
    'chapters_total', 24,
    'chapters_started', (select count(distinct chapter) from attempts where student_id = v and chapter between 1 and 24),
    'chapters_cleared', (select count(*) from chapter_progress where student_id = v and coalesce(quiz_best,0) > 0),
    'chapters_mastered', (select count(*) from chapter_progress where student_id = v and coalesce(quiz_best,0) >= 80),
    'weak_flags', (select count(*) from chapter_progress where student_id = v and weak),

    -- six weeks of accuracy, oldest first
    'weeks', (
      select coalesce(json_agg(json_build_object(
               'week', w.start, 'attempts', coalesce(a.n,0), 'accuracy', coalesce(a.pct,0)) order by w.start), '[]'::json)
      from (select generate_series(v_today - 35, v_today, interval '7 days')::date as start) w
      left join lateral (
        select count(*) n,
               round(100.0*count(*) filter (where ok)/greatest(count(*),1)) pct
        from attempts
        where student_id = v and created_at::date >= w.start and created_at::date < w.start + 7
      ) a on true
    ),

    'exams', exam_readiness_for(v),
    'next_session', (select min(day) from plan_days where student_id = v and day > v_today and lane <> 'R'),
    'plan_end', (select max(day) from plan_days where student_id = v)
  ) into v_out;
  return v_out;
end $$;
