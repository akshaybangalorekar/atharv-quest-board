-- ============================================================================
-- 100_official_topics.sql
-- The topic lists come from what each provider publishes, not from anything
-- uploaded here:
--   AMC      — amt.edu.au/amc: basic arithmetic; fractions and ratios; algebra
--              and pre-algebra; geometry; measurement; statistics and
--              probability; problem-solving (including enumeration)
--   ICAS     — icasassessments.com: number and arithmetic; algebra and patterns;
--              chance and data; measures and units; space and geometry
--   AAS      — academicassessment.com.au: numbers; measurements; space and
--              geometry; data; patterns and algebra; working mathematically
--   Edutest  — edutest.com.au: numerical reasoning is series, matrices,
--              arithmetical reasoning, deduction; mathematics is number,
--              measurement, algebra, space, data
--   APSMO    — apsmo.edu.au publishes no topic list: Division J is four contests
--              of five problems. Its strands are the four contests plus the
--              preparation kit, which is what it actually provides.
-- Run after 099. Safe to re-run.
-- ============================================================================

delete from problem_answers where chapter >= 100;
delete from problems where chapter >= 100;
delete from chapters where n >= 100;

select seed_topics('AAS numerical reasoning', array[
  'Numbers','Measurements','Space and geometry','Data','Patterns and algebra','Working mathematically']);

select seed_topics('Edutest numerical reasoning', array[
  'Series','Matrices','Arithmetical reasoning','Deduction']);

select seed_topics('ELMS', array[
  'Number','Measurement','Algebra','Space','Data']);

select seed_topics('ICAS Maths', array[
  'Number and arithmetic','Algebra and patterns','Chance and data','Measures and units','Space and geometry']);

select seed_topics('AMC Upper Primary', array[
  'Basic arithmetic','Fractions and ratios','Algebra and pre-algebra','Geometry',
  'Measurement','Statistics and probability','Problem-solving']);

-- APSMO: four contests and the preparation kit, which is what it publishes
do $$
declare
  v_names text[] := array['Contest 1','Contest 2','Contest 3','Contest 4','Preparation kit'];
  v_t text; v_n int;
begin
  foreach v_t in array v_names loop
    if exists (select 1 from chapters where title = 'Olympiad · ' || v_t) then continue; end if;
    select min(g) into v_n from generate_series(141,160) g
     where not exists (select 1 from chapters c where c.n = g);
    if v_n is null then select (select coalesce(max(n),0) from chapters)+1 into v_n; end if;
    insert into chapters (n, title, pages, examples, practice, tier, source)
    values (v_n, 'Olympiad · ' || v_t, null, 0, 0, 1, 'apsmo') on conflict (n) do nothing;
  end loop;
end $$;

update chapters set practice = (select count(*) from problems p where p.chapter = chapters.n);
