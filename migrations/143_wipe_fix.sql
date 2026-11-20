-- 143: wipe_history referenced tables that do not exist (journal) and columns that do not
-- exist (formula_board.created_at, exam_mocks.created_at), so the button failed outright.
-- Rewritten against the real schema.
create or replace function wipe_history(p_from date default null)
returns json language plpgsql security definer set search_path = public as $$
declare v uuid := coalesce(viewing_student(), auth.uid());
        a int := 0; s int := 0; m int := 0; r int := 0; b int := 0; n int := 0;
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;
  delete from attempts where student_id = v and (p_from is null or created_at >= p_from);
  get diagnostics a = row_count;
  delete from sessions where student_id = v and (p_from is null or day >= p_from);
  get diagnostics s = row_count;
  delete from exam_mocks where student_id = v and (p_from is null or coalesce(taken_at, started_at) >= p_from);
  get diagnostics m = row_count;
  delete from self_reports where student_id = v and (p_from is null or created_at >= p_from);
  get diagnostics r = row_count;
  delete from formula_board where student_id = v and (p_from is null or added_at >= p_from);
  get diagnostics b = row_count;
  delete from session_notes where student_id = v and (p_from is null or created_at >= p_from);
  get diagnostics n = row_count;
  delete from quest_sessions where student_id = v;
  update profiles p set xp = coalesce((select sum(case when ok then 10 else 0 end)
                                       from attempts where student_id = v), 0)
   where p.student_id = v;
  return json_build_object('attempts', a, 'sessions', s, 'mocks', m, 'reports', r,
                           'board', b, 'notes', n, 'from', p_from);
end $$;
grant execute on function wipe_history(date) to authenticated;
