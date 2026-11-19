create or replace function coach_context()
returns json
language plpgsql security definer set search_path = public as $$
declare
  v uuid := auth.uid();
  v_today date := (now() at time zone 'Australia/Melbourne')::date;
  v_chapter int;
  v_out json;
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;

  select chapter into v_chapter from plan_days
   where student_id = v and day = v_today and lane = 'Q' and chapter is not null
   order by seq limit 1;

  select json_build_object(
    'today', v_today,
    'name', (select name from profiles where student_id = v),
    'xp', coalesce((select xp from profiles where student_id = v),0),
    'streak', coalesce((select streak_days from profiles where student_id = v),0),
    'days_in', (v_today - coalesce((select start_date from profiles where student_id = v), v_today)) + 1,
    'is_first_day', not exists (select 1 from attempts where student_id = v),
    'reset_at', (select reset_at from profiles where student_id = v),
    'sessions_7d', (select count(*) from sessions where student_id = v and day > v_today - 7),
    'days_since_last', (v_today - coalesce((select max(day) from sessions where student_id = v), v_today)),
    'accuracy_7d', coalesce((select round(100.0 * count(*) filter (where ok) / greatest(count(*),1))
                      from attempts where student_id = v and created_at > now() - interval '7 days'), 0),
    'avg_seconds', coalesce((select round(avg(seconds)) from attempts
                      where student_id = v and seconds is not null and created_at > now() - interval '14 days'), 0),
    'plan', coalesce((select json_agg(json_build_object('lane',lane,'chapter',chapter,
                       'questions',target_questions,'minutes',minutes,'note',note) order by seq)
                      from plan_days where student_id = v and day = v_today), '[]'::json),
    'chapter', v_chapter,
    'chapter_title', (select title from chapters where n = v_chapter),
    'chapter_notes', coalesce((select json_build_object('ideas',ideas) from chapter_notes where chapter = v_chapter), '{}'::json),
    'weak', coalesce((select json_agg(json_build_object('technique',technique,'items',open_items))
                      from v_weak_techniques where student_id = v limit 3), '[]'::json),
    'today_attempts', coalesce((select json_agg(json_build_object('chapter',chapter,'idx',idx,'ok',ok) order by created_at desc)
                      from attempts where student_id = v and created_at >= v_today limit 20), '[]'::json),
    'self_reports', coalesce((select json_agg(json_build_object('day',day,'chapter',chapter,'minutes',minutes,'note',note,'confidence',confidence) order by day desc)
                      from (select * from self_reports where student_id = v order by day desc limit 5) t), '[]'::json),
    'recent_chat', coalesce((select json_agg(json_build_object('role',role,'body',body) order by created_at)
                      from (select * from chat_messages where student_id = v and coalesce(thread,'child') = 'child' order by created_at desc limit 12) t), '[]'::json),
    'recent_tests', coalesce((select json_agg(json_build_object('kind',kind,'pct',pct,'taken_at',taken_at) order by taken_at desc)
                      from exam_mocks where student_id = v limit 3), '[]'::json),
    'readiness', coalesce((select json_agg(json_build_object('exam',exam,'verdict',verdict,'message',message))
                      from v_exam_readiness), '[]'::json),
    'mock', mock_due(v),
    'placement_due', placement_due(v),
    'focus', teaching_focus(),
    'recent_parent_chat', coalesce((select json_agg(json_build_object('role',role,'body',body) order by created_at)
                      from (select * from chat_messages where student_id = v and thread = 'parent'
                             order by created_at desc limit 12) t), '[]'::json),
    'training', training_view()->'sources',
    'material', search_docs(
        coalesce((select title from chapters where n = v_chapter), 'mathematics problem solving'),
        v_chapter, 4),
    'training_status', training_status(),
    'open_paper', open_paper(),
    'truth', truth(),
    'banks', (truth()->'content'->'banks')
  ) into v_out;
  return v_out;
end $$;
grant execute on function coach_context() to authenticated;
