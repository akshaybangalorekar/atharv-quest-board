-- ============================================================================
-- 123_doc_store.sql — the material she can read, and the check every question
-- must pass before a child sees it.
-- ============================================================================

create table if not exists source_docs (
  id          bigserial primary key,
  student_id  uuid,
  kind        text not null,                 -- upload | web
  title       text not null,
  url         text,
  source_id   bigint,
  fetched_at  timestamptz not null default now(),
  pages       int default 0,
  chars       int default 0
);

create table if not exists doc_chunks (
  id       bigserial primary key,
  doc_id   bigint not null references source_docs(id) on delete cascade,
  chapter  int,
  topic    text,
  body     text not null,
  tsv      tsvector generated always as (to_tsvector('english', body)) stored
);

create index if not exists doc_chunks_tsv on doc_chunks using gin (tsv);
create index if not exists doc_chunks_doc on doc_chunks (doc_id);

-- questions carry their verdict
alter table problems add column if not exists verified boolean not null default false;
alter table problems add column if not exists verified_at timestamptz;
alter table problems add column if not exists verify_note text;

-- store one document and its chunks
create or replace function store_doc(p_kind text, p_title text, p_url text default null,
                                     p_source_id bigint default null, p_chunks jsonb default '[]'::json)
returns bigint
language plpgsql security definer set search_path = public as $$
declare v uuid := coalesce(viewing_student(), auth.uid()); v_doc bigint; v_chars int := 0; c jsonb;
begin
  insert into source_docs (student_id, kind, title, url, source_id)
  values (v, p_kind, p_title, p_url, p_source_id) returning id into v_doc;

  for c in select * from json_array_elements(coalesce(p_chunks, '[]'::json)) loop
    insert into doc_chunks (doc_id, chapter, topic, body)
    values (v_doc, nullif(c->>'chapter','')::int, c->>'topic', coalesce(c->>'body',''));
    v_chars := v_chars + length(coalesce(c->>'body',''));
  end loop;

  update source_docs set chars = v_chars,
         pages = coalesce(json_array_length(p_chunks), 0) where id = v_doc;
  return v_doc;
end $$;

-- the nearest passages for a topic
create or replace function search_docs(p_query text, p_chapter int default null, p_limit int default 4)
returns json
language sql security definer set search_path = public as $$
  with q as (select websearch_to_tsquery('english', coalesce(nullif(btrim(p_query), ''), 'maths')) as t)
  select coalesce((select json_agg(row_to_json(x) order by x.rank desc) from (
    select c.body, c.topic, d.title, d.url, d.kind,
           ts_rank(c.tsv, q.t) as rank
    from doc_chunks c join source_docs d on d.id = c.doc_id, q
    where c.tsv @@ q.t
      and (p_chapter is null or c.chapter is null or c.chapter = p_chapter)
    order by ts_rank(c.tsv, q.t) desc
    limit greatest(1, coalesce(p_limit, 4))) x), '[]'::json);
$$;

create or replace function training_status()
returns json
language sql security definer set search_path = public as $$
  select json_build_object(
    'docs', (select count(*) from source_docs),
    'chunks', (select count(*) from doc_chunks),
    'web_docs', (select count(*) from source_docs where kind = 'web'),
    'upload_docs', (select count(*) from source_docs where kind = 'upload'),
    'last_fetch', (select max(fetched_at) from source_docs where kind = 'web'),
    'verified', (select count(*) from problems where verified),
    'unverified', (select count(*) from problems where not verified),
    'failed_check', (select count(*) from problems where verify_note is not null)
  );
$$;

grant execute on function store_doc(text, text, text, bigint, jsonb) to authenticated;
grant execute on function search_docs(text, int, int) to authenticated;
grant execute on function training_status() to authenticated;
