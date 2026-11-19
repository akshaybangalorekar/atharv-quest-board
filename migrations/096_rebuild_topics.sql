-- ============================================================================
-- 096_rebuild_topics.sql
-- The strand list had accumulated names from earlier uploads and earlier seeds.
-- With no questions anywhere, the whole thing is rebuilt once, cleanly, from a
-- fixed list per exam. Nothing here creates a question.
-- Run after 095. Safe to re-run.
-- ============================================================================

delete from problem_answers where chapter >= 100;
delete from problems where chapter >= 100;
delete from chapters where n >= 100;

select seed_topics('AAS numerical reasoning', array[
  'Number','Measurement','Space and geometry','Data','Patterns and algebra','Working mathematically']);

select seed_topics('Edutest numerical reasoning', array[
  'Number series','Number matrices','Arithmetical reasoning','Deduction','Data and tables','Estimation']);

select seed_topics('ELMS', array[
  'Number','Fractions, decimals and percentages','Ratio and rates','Measurement','Geometry and space','Data and statistics']);

select seed_topics('ICAS Maths', array[
  'Number and algebra','Measurement and geometry','Statistics and probability','Measures and units','Space and geometry']);

select seed_topics('AMC Upper Primary', array[
  'Number','Patterns and algebra','Measurement','Geometry and space','Chance and data','Problem solving']);

-- the contest sets are sets, not topics: nine of them, named plainly
do $$
declare i int; v_n int;
begin
  for i in 1..9 loop
    if exists (select 1 from chapters where title = 'Olympiad · Contest set ' || i) then continue; end if;
    select min(g) into v_n from generate_series(141,160) g
     where not exists (select 1 from chapters c where c.n = g);
    if v_n is null then select (select coalesce(max(n),0) from chapters)+1 into v_n; end if;
    insert into chapters (n, title, pages, examples, practice, tier, source)
    values (v_n, 'Olympiad · Contest set ' || i, null, 0, 0, 1, 'apsmo') on conflict (n) do nothing;
  end loop;
end $$;

update chapters set practice = (select count(*) from problems p where p.chapter = chapters.n);
