-- tests/tests_schema.sql — invariants the database itself must keep.
--
-- Written after a real failure: two versions of store_doc existed, PostgREST could not choose
-- between them, and every training run failed while the screen said nothing. These checks make
-- that class of fault loud, and they run in a second.

begin;

-- 1. no ambiguous function: two overloads where one's arguments are a prefix of another cannot
--    be resolved by PostgREST, so the call fails at runtime with a message nobody reads.
with sigs as (
  select p.proname,
         array(select t.typname from unnest(p.proargtypes) with ordinality as x(oid, ord)
               join pg_type t on t.oid = x.oid order by ord) as args
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
),
pairs as (
  select a.proname, a.args as shorter, b.args as longer
  from sigs a join sigs b on a.proname = b.proname and a.args <> b.args
  where a.args = b.args[1:array_length(a.args, 1)]
)
select 'no ambiguous overloads' as check_name,
       coalesce((select count(*) from pairs), 0) as found,
       coalesce((select string_agg(proname, ', ') from pairs), 'none') as detail;

-- 2. one store_doc, one signature, with the authority argument present
select 'store_doc has one signature' as check_name,
       count(*) as found,
       coalesce(string_agg(pg_get_function_identity_arguments(p.oid), ' | '), 'missing') as detail
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'store_doc';

-- 3. every question that can be served carries a gate verdict (or is explicitly provisional)
select 'served questions are gated' as check_name,
       count(*) filter (where gate_state is null) as found,
       'questions with no gate verdict' as detail
from problems;

-- 4. no question is served after failing its check
select 'nothing failed is served' as check_name,
       count(*) as found,
       'failed questions visible through v_problems_ok' as detail
from v_problems_ok where gate_state = 'failed';

-- 5. every strand belongs to an exam — an orphan strand is a naming bug waiting to happen
select 'every strand has an exam' as check_name,
       count(*) as found,
       coalesce(string_agg(title, ', '), 'none') as detail
from strands where exam_id is null;

-- 6. official material is scoped to a real exam key
select 'authority names a real exam' as check_name,
       count(*) as found,
       coalesce(string_agg(distinct authority, ', '), 'none') as detail
from source_docs
where authority is not null
  and split_part(authority, '_', 2) not in (select key from exams);

rollback;
