-- ============================================================================
-- 094_topics_all_exams.sql
-- Olympiad had twenty-four topics because they are the chapters of the study
-- guide. Every other exam had none, because their strands only ever came into
-- being when a paper was uploaded. They now have topics too, taken from what
-- each test provider says it covers.
--   Edutest numerical reasoning — series, matrices, arithmetical reasoning,
--     deduction, data and estimation (edutest.com.au; selectiveready.com)
--   Edutest / ELMS mathematics — number, fractions and percentages, ratio and
--     rates, measurement, geometry and space, data and statistics
--   AAS (Camberwell) — number, measurement, space and geometry, data, patterns
--     and algebra, working mathematically (as AAS lists its maths areas)
--   ICAS Paper D — number and algebra, measurement and geometry, statistics and
--     probability, measures and units, space and geometry
--   AMC Upper Primary — number, patterns and algebra, measurement, geometry and
--     space, chance and data, problem solving
-- No questions are created here: topics only.
-- Run after 093. Safe to re-run.
-- ============================================================================

create or replace function seed_topics(p_exam text, p_topics text[])
returns int
language plpgsql security definer set search_path = public as $$
declare
  v_bank exam_banks;
  v_label text;
  v_added int := 0;
  v_n int;
  v_t text;
begin
  select * into v_bank from exam_banks where exam = p_exam;
  if not found then raise exception 'unknown exam %', p_exam; end if;
  v_label := family_label(v_bank.kind);

  foreach v_t in array p_topics loop
    if exists (select 1 from chapters where title = v_label || ' · ' || v_t) then continue; end if;

    select min(g) into v_n
    from generate_series(v_bank.chapter_from, v_bank.chapter_to) g
    where not exists (select 1 from chapters c where c.n = g);

    if v_n is null then
      select (select coalesce(max(n),0) from chapters) + 1 into v_n;
    end if;

    insert into chapters (n, title, pages, examples, practice, tier, source)
    values (v_n, v_label || ' · ' || v_t, null, 0, 0, 1, v_bank.kind)
    on conflict (n) do nothing;
    v_added := v_added + 1;
  end loop;

  return v_added;
end $$;

grant execute on function seed_topics(text, text[]) to authenticated, service_role;

select seed_topics('Edutest numerical reasoning',
  array['Number series','Number matrices','Arithmetical reasoning','Deduction','Data and tables','Estimation']);

select seed_topics('ELMS',
  array['Number','Fractions, decimals and percentages','Ratio and rates','Measurement','Geometry and space','Data and statistics']);

select seed_topics('AAS numerical reasoning',
  array['Number','Measurement','Space and geometry','Data','Patterns and algebra','Working mathematically']);

select seed_topics('ICAS Maths',
  array['Number and algebra','Measurement and geometry','Statistics and probability','Measures and units','Space and geometry']);

select seed_topics('AMC Upper Primary',
  array['Number','Patterns and algebra','Measurement','Geometry and space','Chance and data','Problem solving']);

update chapters set practice = (select count(*) from problems p where p.chapter = chapters.n);
