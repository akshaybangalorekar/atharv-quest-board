-- 131_authority.sql — Top Scope is identified by the upload checkbox, not by the file name.
alter table papers add column if not exists authority text;
alter table problems add column if not exists authority text;
alter table source_docs add column if not exists authority text;
create index if not exists problems_authority on problems (authority);

create or replace function authority_material(p_exam text, p_limit int default 6)
returns json language sql security definer set search_path = public as $$
  select coalesce((select json_agg(row_to_json(x)) from (
    select c.body, d.title, d.url, d.authority
    from doc_chunks c join source_docs d on d.id = c.doc_id
    where d.authority = 'topscope_' || p_exam
    order by c.id desc limit greatest(1, coalesce(p_limit, 6))) x), '[]'::json);
$$;
grant execute on function authority_material(text, int) to authenticated;

create or replace function stamp_authority(p_paper bigint)
returns int language plpgsql security definer set search_path = public as $$
declare v_auth text; v_n int;
begin
  select authority into v_auth from papers where id = p_paper;
  if v_auth is null then return 0; end if;
  update problems set authority = v_auth where paper_id = p_paper;
  get diagnostics v_n = row_count;
  return v_n;
end $$;
grant execute on function stamp_authority(bigint) to authenticated;

create or replace function exam_questions(p_exam text)
returns table (chapter int, idx int, prompt text, authority text, verified boolean)
language sql security definer set search_path = public as $$
  select p.chapter, p.idx, p.prompt, p.authority, p.verified
  from problems p join strands s on s.n = p.chapter join exams e on e.id = s.exam_id
  where e.key = p_exam;
$$;
grant execute on function exam_questions(text) to authenticated;
