-- 133_gate.sql — the gate a question must pass before it is served.
alter table problems add column if not exists gate_state text;
alter table problems add column if not exists gate_at timestamptz;
alter table problems add column if not exists gate_note text;

create or replace view v_problems_ok as
  select p.* from problems p
  where p.verify_note is null and p.verified
    and coalesce(p.gate_state, 'provisional') in ('cleared', 'provisional');

create or replace function exam_has_official(p_exam text)
returns boolean language sql security definer set search_path = public as $$
  select exists (select 1 from source_docs d where d.authority = 'official_' || p_exam)
      or exists (select 1 from source_docs d where d.authority = 'topscope_' || p_exam);
$$;
grant execute on function exam_has_official(text) to authenticated;

create or replace function strand_exam(p_chapter int)
returns json language sql security definer set search_path = public as $$
  select json_build_object('exam', e.key, 'official', exam_has_official(e.key))
  from strands s join exams e on e.id = s.exam_id where s.n = p_chapter;
$$;
grant execute on function strand_exam(int) to authenticated;
