-- 135_store_doc_one.sql — one store_doc, so PostgREST cannot be ambiguous.
drop function if exists store_doc(text, text, text, bigint, jsonb);
drop function if exists store_doc(text, text, text, bigint, jsonb, text);
