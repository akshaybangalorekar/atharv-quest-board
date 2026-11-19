-- ============================================================================
-- 088_strand_names.sql
-- Strand titles still carried the old bank names — "APSMO Division J · Geometry",
-- "ELMS · Number" — so the child saw APSMO on his screen even though the parent
-- table had folded it into Olympiad. Every strand is named after its family now,
-- and new strands are created that way.
-- Run after 087. Safe to re-run.
-- ============================================================================

update chapters c
   set title = f.label || split_part(c.title, '·', 2)
  from (
    select 'book'::text as kind, 'Olympiad'::text as label
    union all select 'apsmo', 'Olympiad'
    union all select 'edutest', 'Edutest'
    union all select 'elms', 'Edutest'
    union all select 'aas', 'AAS'
    union all select 'icas', 'ICAS'
    union all select 'amc', 'AMC'
  ) f
 where c.source = f.kind
   and position('·' in c.title) > 0
   and c.title not like f.label || ' ·%';

create or replace function family_label(p_kind text)
returns text language sql immutable as $$
  select case p_kind
    when 'book' then 'Olympiad' when 'apsmo' then 'Olympiad' when 'olympiad' then 'Olympiad'
    when 'edutest' then 'Edutest' when 'elms' then 'Edutest'
    when 'aas' then 'AAS' when 'icas' then 'ICAS' when 'amc' then 'AMC'
    else initcap(p_kind) end;
$$;

create or replace function chapter_for_strand(p_exam text, p_strand text)
returns int
language plpgsql security definer set search_path = public as $$
declare
  v_bank exam_banks;
  v_label text;
  v_title text;
  v_n int;
begin
  select * into v_bank from exam_banks where exam = p_exam;
  if not found then raise exception 'unknown exam %', p_exam; end if;

  v_label := family_label(v_bank.kind);
  v_title := v_label || ' · ' || coalesce(nullif(btrim(p_strand),''), 'General');

  select n into v_n from chapters where title = v_title limit 1;
  if v_n is not null then return v_n; end if;

  -- the first free number in this bank's own range
  select min(g) into v_n
  from generate_series(v_bank.chapter_from, v_bank.chapter_to) g
  where not exists (select 1 from chapters c where c.n = g);

  if v_n is null then
    select (select coalesce(max(n), 0) from chapters) + 1 into v_n;
  end if;

  insert into chapters (n, title, pages, examples, practice, tier, source)
  values (v_n, v_title, null, 0, 0, 1, v_bank.kind)
  on conflict (n) do nothing;

  select n into v_n from chapters where title = v_title limit 1;
  return v_n;
end $$;

grant execute on function chapter_for_strand(text, text) to authenticated, service_role;
grant execute on function family_label(text) to authenticated, service_role;
