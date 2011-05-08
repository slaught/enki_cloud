begin;

insert into node_type (node_type) values ('physical')
, ('virtual')
, ( 'switch')
, ('pdu') 
, ('serial console') 
, ('sensors') 
, ('load balancer') 
, ('san') 
, ('fan') 
;

insert into cnu_net.protocols (proto) values ('tcp'),('udp'),('icmp');

insert into disk_types (id, disk_type)
values (DEFAULT, 'direct'),(DEFAULT,'file'),(DEFAULT,'iscsi');
commit; begin;
insert into serial_baud_rates (speed)
values
(57600),
(115200),
(38400),
(19200),
(9600),
(300)
;

commit; begin;
insert into cnu_net.distributions (name) values
('Debian Lenny'),
('Ubuntu Dapper'),
('Ubuntu Hardy'),
('Debian Etch'),
('Debian Etch and a Half')
;
insert into cnu_net.os_versions
 (distribution , kernel ) values 
 ('Debian Lenny' ,'2.6.26-1-xen-amd64'),
 ('Debian Lenny' ,'2.6.26-1-xen-686'),
 ('Debian Etch'  ,'2.6.18-6-xen-686'),
 ('Debian Etch'  ,'2.6.18-6-xen-amd64'),
 ('Debian Etch'  ,'2.6.18-4-xen-686'),
 ('Ubuntu Dapper','2.6.18-6-xen-686'),
 ('Ubuntu Dapper','2.6.18-4-xen-686')
;

insert into roles 
(name, description, grant_select, grant_update, grant_delete, grant_create, grant_insert )
values
('admin','Admin Role: full access', true, true, true,  true, true),
('guest','Guest Role: read only access', true, false, false, false , false),
('operator','Operator Minor updates and new nodes', true, true, false, false , true),
('sysadmin','Sysadmin Full updates and add to clusters', true, true , false, true  , true ),
('engineer','Engineer Role: create clusters and delete ', true, true, true, true , true )
, ('dba','Database admin Role: manage databases and minor updates ', true, true, false,  true, true)
, ('rampart_admin', 'Administrator for ramparts', true, true, true, true, true)
, ('network_admin', 'network enginnering', true, true, false, true, true)
;
commit;

begin;
-- database 
insert into database_versions (version)
values (8.3),(8.4),(9.0);

-- auth mehtods 
insert into database_auth_methods (auth_method) values 
('md5'), ('ldap'), ('krb'), ('ident')
,('ident pgadmin')
,('ident sameuser')
;

insert into rampart_service_templates (description, network, port, protocol, direction) 
values
-- outbound
  ('HTTP Internet Access (PAT) (Outbound)', '0.0.0.0/0', 80, 'tcp', 'out'),
  ('HTTPS Internet Access (PAT) (Outbound)', '0.0.0.0/0', 443, 'tcp', 'out'),
-- inbound
  ('SSH Service (Inbound)', '0.0.0.0/0', 22, 'tcp', 'in'),
  ('HTTP Service (Inbound)', '0.0.0.0/0', 80, 'tcp', 'in'),
  ('HTTPS Service (Inbound)', '0.0.0.0/0', 443, 'tcp', 'in'),
  ('Postgresql Service (Inbound)', '0.0.0.0/0', 5432, 'tcp', 'in')
;
commit;
begin;
-- network types
insert into network_types (name) values 
 ('dummy')
, ('mgmt')
,('public')
,('campus')
,('private')
,('cluster')
,('routable')
,('locale')
,('interconnect')
,('san')
;
commit;
