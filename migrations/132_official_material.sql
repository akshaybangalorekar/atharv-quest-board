-- 132_official_material.sql — official training material, scoped to one exam, chosen by the upload dropdown + box.
create or replace function authority_material(p_exam text, p_limit int default 6)
returns json language sql security definer set search_path = public as $$
  select coalesce((select json_agg(row_to_json(x)) from (
    select c.body, d.title, d.url, d.authority
    from doc_chunks c join source_docs d on d.id = c.doc_id
    where d.authority in ('official_' || p_exam, 'topscope_' || p_exam)
    order by c.id desc limit greatest(1, coalesce(p_limit, 6))) x), '[]'::json);
$$;
grant execute on function authority_material(text, int) to authenticated;
