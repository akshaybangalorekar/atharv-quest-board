-- ============================================================================
-- 066_parent_child_id.sql
-- The parent screen needs to know which child it is looking at, to set their
-- password or remove the account.
-- Run after 065. Safe to re-run.
-- ============================================================================

create or replace function parent_context()
returns json
language plpgsql security definer set search_path = public as $$
declare
  v_student uuid := viewing_student();
  v_out json;
begin
  if not is_parent() then
    raise exception 'only a parent can open this' using errcode = '42501';
  end if;
  if v_student is null then
    return json_build_object('student', null, 'student_id', null, 'readiness', '[]'::json);
  end if;

  select json_build_object(
    'student_id', v_student,
    'student', (select name from profiles where student_id = v_student),
    'xp', coalesce((select xp from profiles where student_id = v_student),0),
    'streak', coalesce((select streak_days from profiles where student_id = v_student),0),
    'attempts_total', (select count(*) from attempts where student_id = v_student),
    'attempts_7d', (select count(*) from attempts where student_id = v_student and created_at > now() - interval '7 days'),
    'accuracy_7d', coalesce((select round(100.0 * count(*) filter (where ok) / greatest(count(*),1))
                      from attempts where student_id = v_student and created_at > now() - interval '7 days'), 0),
    'sessions_7d', (select count(*) from sessions where student_id = v_student and day > current_date - 7),
    'readiness', exam_readiness_for(v_student),
    'banks', coalesce((select json_agg(json_build_object('exam',exam,'kind',kind,'from',chapter_from,'to',chapter_to)) from exam_banks), '[]'::json),
    'weak', coalesce((select json_agg(json_build_object('technique',technique,'open',open_items,'misses',misses))
                      from v_weak_techniques where student_id = v_student limit 5), '[]'::json),
    'recent_tests', coalesce((select json_agg(json_build_object('kind',kind,'pct',pct,'score',score,'total',total,'taken_at',taken_at) order by taken_at desc)
                      from exam_mocks where student_id = v_student limit 5), '[]'::json),
    'chapters', coalesce((select json_agg(json_build_object('chapter',chapter,'quiz_best',quiz_best,'weak',weak))
                      from chapter_progress where student_id = v_student), '[]'::json)
  ) into v_out;

  return v_out;
end $$;
