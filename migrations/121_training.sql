-- ============================================================================
-- 121_training.sql
-- Where the coach draws from: the official providers, verified popular sites,
-- and whatever has been uploaded. This is a source list, not a model weight —
-- it is what she is told she may use, and what the parent can see and extend.
-- Run after 120. Safe to re-run.
-- ============================================================================

create table if not exists training_sources (
  id        bigserial primary key,
  name      text not null,
  url       text,
  kind      text not null default 'official',   -- official | popular | uploaded
  family    text,                               -- aas | edutest | apsmo | amc | icas | general
  note      text,
  active    boolean not null default true,
  added_at  timestamptz not null default now()
);

insert into training_sources (name, url, kind, family, note) values
  ('Australian Maths Trust — AMC',        'https://www.amt.edu.au/amc',                 'official', 'amc',      'the AMC papers and solutions'),
  ('ICAS Assessments',                    'https://www.icasassessments.com/',           'official', 'icas',     'ICAS paper formats and sample questions'),
  ('APSMO — Maths Olympiad',              'https://apsmo.edu.au/',                      'official', 'apsmo',    'Division J contest papers'),
  ('Edutest',                             'https://www.edutest.com.au/',                'official', 'edutest',  'test structure and sample papers'),
  ('Academic Assessment Services (AAS)',  'https://www.academicassessment.com.au/',     'official', 'aas',      'scholarship test structure'),
  ('Khan Academy — arithmetic and pre-algebra', 'https://www.khanacademy.org/math',      'popular',  'general',  'free, well-sequenced practice'),
  ('NRICH (Cambridge)',                   'https://nrich.maths.org/',                   'popular',  'general',  'problem-solving tasks by topic'),
  ('Maths Is Fun',                        'https://www.mathsisfun.com/',                'popular',  'general',  'plain explanations of methods'),
  ('Australian Maths Competition past papers', 'https://www.amt.edu.au/amc-past-papers', 'popular',  'amc',      'past AMC papers'),
  ('Math Kangaroo',                       'https://www.mathkangaroo.edu.au/',           'popular',  'general',  'competition-style problems')
on conflict do nothing;

create or replace function list_training_sources()
returns json
language sql security definer set search_path = public as $$
  select coalesce((select json_agg(row_to_json(t) order by t.kind, t.name) from (
    select id, name, url, kind, family, note, active, added_at from training_sources) t), '[]'::json);
$$;

create or replace function add_training_source(p_name text, p_url text, p_kind text default 'popular', p_family text default 'general', p_note text default null)
returns json
language plpgsql security definer set search_path = public as $$
begin
  if not is_parent() then raise exception 'only a parent can do this' using errcode = '42501'; end if;
  if coalesce(btrim(p_name), '') = '' then raise exception 'a source needs a name' using errcode = '22023'; end if;
  insert into training_sources (name, url, kind, family, note)
  values (btrim(p_name), nullif(btrim(p_url), ''), coalesce(p_kind,'popular'), coalesce(p_family,'general'), p_note);
  return list_training_sources();
end $$;

create or replace function set_training_source_active(p_id bigint, p_active boolean)
returns json
language plpgsql security definer set search_path = public as $$
begin
  if not is_parent() then raise exception 'only a parent can do this' using errcode = '42501'; end if;
  update training_sources set active = p_active where id = p_id;
  return list_training_sources();
end $$;

create or replace function remove_training_source(p_id bigint)
returns json
language plpgsql security definer set search_path = public as $$
begin
  if not is_parent() then raise exception 'only a parent can do this' using errcode = '42501'; end if;
  delete from training_sources where id = p_id;
  return list_training_sources();
end $$;

grant execute on function list_training_sources() to authenticated;
grant execute on function add_training_source(text, text, text, text, text) to authenticated;
grant execute on function set_training_source_active(bigint, boolean) to authenticated;
grant execute on function remove_training_source(bigint) to authenticated;

-- the sources, plus what has been uploaded, in one read
create or replace function training_view()
returns json
language sql security definer set search_path = public as $$
  with who as (select coalesce(viewing_student(), auth.uid()) as sid)
  select json_build_object(
    'sources', list_training_sources(),
    'uploaded', coalesce((select json_agg(row_to_json(p) order by p.created_at desc) from (
        select id, title, exam, pages, questions, created_at from papers, who
        where student_id = who.sid) p), '[]'::json),
    'generated', coalesce((select count(*) from problems where paper_id is null), 0),
    'from_files', coalesce((select count(*) from problems where paper_id is not null), 0)
  );
$$;
grant execute on function training_view() to authenticated;
