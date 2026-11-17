-- ============================================================================
-- 016_reset.sql
-- Start again from zero, from the parent's login.
-- Run after 015. Safe to re-run.
--
-- Deletes everything that measures him: attempts, weak queue, chapter progress,
-- tests and their questions, badges, sessions, chat and weekly notes. Keeps the
-- timetable, the question bank and the accounts. Irreversible by design.
-- ============================================================================

create or replace function reset_progress(p_confirm text)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v uuid := viewing_student();
  c_attempts int := 0; c_weak int := 0; c_chapters int := 0; c_tests int := 0;
  c_badges int := 0; c_sessions int := 0; c_chats int := 0; c_notes int := 0;
begin
  if not is_parent() then
    raise exception 'only a parent can reset progress' using errcode = '42501';
  end if;
  if v is null then
    raise exception 'no student linked to this login' using errcode = '28000';
  end if;
  if coalesce(p_confirm,'') <> 'RESET' then
    raise exception 'type RESET to confirm' using errcode = '22023';
  end if;

  delete from exam_items where exam_id in (select id from exam_mocks where student_id = v);
  delete from exam_mocks where student_id = v;              get diagnostics c_tests = row_count;
  delete from attempts where student_id = v;                get diagnostics c_attempts = row_count;
  delete from weak_queue where student_id = v;              get diagnostics c_weak = row_count;
  delete from chapter_progress where student_id = v;        get diagnostics c_chapters = row_count;
  delete from badges where student_id = v;                  get diagnostics c_badges = row_count;
  delete from sessions where student_id = v;                get diagnostics c_sessions = row_count;
  delete from chat_messages where student_id = v;           get diagnostics c_chats = row_count;
  delete from weekly_reports where student_id = v;          get diagnostics c_notes = row_count;
  delete from working_reviews where student_id = v;

  update profiles
     set xp = 0, level = 1, streak_days = 0, last_session_date = null
   where student_id = v;

  return json_build_object(
    'attempts', c_attempts, 'weak_items', c_weak, 'chapters', c_chapters,
    'tests', c_tests, 'badges', c_badges, 'sessions', c_sessions,
    'chat_messages', c_chats, 'weekly_notes', c_notes
  );
end $$;
