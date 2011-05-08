
begin;
  create language plpgsql ;
commit;

select datname, datconfig from pg_database where datname = current_database();
begin;
create or replace function config_database_path ()
returns boolean
as $def$
DECLARE
  rec record;
  sql text; 
  my_database name ; 
BEGIN
  my_database :=  current_database();
  set client_min_messages = 'WARNING';
  
  sql :=  'alter database ' || my_database || 
    $path$  set search_path = '$user', 'cnu_net','public' $path$ ;
  execute sql;
  return true;
END;
$def$ language 'plpgsql';

select config_database_path();
select datname, datconfig from pg_database where datname = current_database();

drop function config_database_path ();
commit;
