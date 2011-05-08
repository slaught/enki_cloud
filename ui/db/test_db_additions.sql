set search_path = 'cnu_net', 'public';
-- alternate:
-- select into t array_to_string( ARRAY( 
--              select quote_ident(tablename) from pg_tables where schemaname = 'cnu_net'
--        ), ', ');
-- execute 'truncate table ' || t || ' cascade';
CREATE OR REPLACE FUNCTION truncate_tables()
RETURNS void
AS $$
DECLARE
    r RECORD;
    command TEXT DEFAULT 'truncate table';
BEGIN
    for r IN
      SELECT tablename from pg_tables where schemaname='cnu_net'
    LOOP
      command := command || ' ' || quote_ident(r.tablename) || ',';
    END LOOP;
    command := trim(trailing ',' from command);
    execute command || ' cascade';
END;
$$ LANGUAGE plpgsql;
