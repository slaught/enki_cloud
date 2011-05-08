
create role cnu_it_deploy;
create role cnu_it_config;
create role cnu_it_app;
grant cnu_it_deploy to cnu_it_config;
grant cnu_it_deploy to cnu_it_app; 
grant cnu_it_config to cnu_it_app;

