--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: cnu_net; Type: SCHEMA; Schema: -; Owner: cnu_it_config
--

CREATE SCHEMA cnu_net;


ALTER SCHEMA cnu_net OWNER TO cnu_it_config;

SET search_path = cnu_net, pg_catalog;

--
-- Name: add_guest(integer, integer); Type: FUNCTION; Schema: cnu_net; Owner: cnu_it_config
--

CREATE FUNCTION add_guest(p_host integer, p_guest integer) RETURNS integer
    AS $$
DECLARE
  rc cnu_net.xen_mappings.id%type;
BEGIN
  perform assert(is_host(p_host), 'not a host: ' || p_host::text );
  perform assert(is_guest(p_guest), 'not a guest: '|| p_guest::text);
 insert into cnu_net.xen_mappings (id, host_id, guest_id) 
   values ( DEFAULT, p_host, p_guest ) returning id into rc;
 return rc;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION cnu_net.add_guest(p_host integer, p_guest integer) OWNER TO cnu_it_config;

--
-- Name: add_guest(text, text); Type: FUNCTION; Schema: cnu_net; Owner: cnu_it_config
--

CREATE FUNCTION add_guest(i_host text, i_guest text) RETURNS integer
    AS $$
DECLARE
 h int;
 g int;
BEGIN
  select into h node_id from cnu_net.nodes where hostname = i_host;
  select into g node_id from cnu_net.nodes where hostname = i_guest;
  return cnu_net.add_guest(h,g);
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION cnu_net.add_guest(i_host text, i_guest text) OWNER TO cnu_it_config;

--
-- Name: all_ip_addresses(cidr, numeric); Type: FUNCTION; Schema: cnu_net; Owner: cnu_it_config
--

CREATE FUNCTION all_ip_addresses(p_network_range cidr, p_skip numeric) RETURNS SETOF inet
    AS $$
DECLARE
  max_ip inet;   gw_ip inet;
  min_octet int; max_octet int;
  netmask int;
BEGIN
  netmask  := masklen(p_network_range);
  max_ip   := broadcast(p_network_range);
  gw_ip    := p_network_range::inet;
  min_octet :=  round(abs(p_skip::integer));
  max_octet := (max_ip - gw_ip) - 1;
  if min_octet < 1 then
    min_octet := 1;
  end if;
  if max_octet < min_octet then 
    min_octet := max_octet;
  end if;
  -- force netmask to match ip_range with set_masklen
  return query SELECT set_masklen(gw_ip + s, netmask) as ip_address 
          FROM generate_series(min_octet,max_octet,1) as s(a) 
  ;
END; 
$$
    LANGUAGE plpgsql;


ALTER FUNCTION cnu_net.all_ip_addresses(p_network_range cidr, p_skip numeric) OWNER TO cnu_it_config;

--
-- Name: all_ip_addresses(cidr); Type: FUNCTION; Schema: cnu_net; Owner: cnu_it_config
--

CREATE FUNCTION all_ip_addresses(cidr) RETURNS SETOF inet
    AS $_$ select * from all_ip_addresses($1, 20); $_$
    LANGUAGE sql;


ALTER FUNCTION cnu_net.all_ip_addresses(cidr) OWNER TO cnu_it_config;

--
-- Name: all_ip_addresses(text); Type: FUNCTION; Schema: cnu_net; Owner: cnu_it_config
--

CREATE FUNCTION all_ip_addresses(text) RETURNS SETOF inet
    AS $_$ select * from all_ip_addresses(cast($1 as cidr), 20); $_$
    LANGUAGE sql;


ALTER FUNCTION cnu_net.all_ip_addresses(text) OWNER TO cnu_it_config;

--
-- Name: assigned_network_ip_addresses(integer); Type: FUNCTION; Schema: cnu_net; Owner: cnu_it_config
--

CREATE FUNCTION assigned_network_ip_addresses(integer) RETURNS SETOF inet
    AS $_$ select ip_address from ip_addresses where network_id = $1 ; $_$
    LANGUAGE sql;


ALTER FUNCTION cnu_net.assigned_network_ip_addresses(integer) OWNER TO cnu_it_config;

--
-- Name: check_unique_ip_address(); Type: FUNCTION; Schema: cnu_net; Owner: cnu_it_config
--

CREATE FUNCTION check_unique_ip_address() RETURNS trigger
    AS $$
DECLARE
   net_type text;
   n  integer;
BEGIN
   select into net_type network_types.name
      from networks join network_types using (network_type_id)
      where network_id = NEW.network_id ;
   -- RAISE NOTICE '%: Searching for % of %', TG_OP, host(NEW.ip_address), net_type;
   select into n count(*) from ip_addresses
      where set_masklen(ip_address,32) = set_masklen(NEW.ip_address, 32);
   IF (TG_OP = 'UPDATE') THEN
      IF ( OLD.ip_address == NEW.ip_address) THEN
        RETURN NEW;
      END IF;
      If net_type <> 'private' and n > 1 THEN
      RAISE EXCEPTION 'Duplicate IP ADDRESS: % -> % not allowed', OLD.ip_address, NEW.ip_address;
      END IF;
  ELSIF (TG_OP = 'INSERT') THEN
      IF net_type <> 'private' and n > 1 THEN
        RAISE EXCEPTION 'Duplicate IP ADDRESS: % not allowed', NEW.ip_address;
      end if;
  END IF;
  RETURN NULL;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION cnu_net.check_unique_ip_address() OWNER TO cnu_it_config;

--
-- Name: datacenter_mgmt_network_id(integer); Type: FUNCTION; Schema: cnu_net; Owner: cnu_it_config
--

CREATE FUNCTION datacenter_mgmt_network_id(integer) RETURNS integer
    AS $_$
 select network_id from networks
  join network_types using (network_type_id)
  where network_types.name = 'mgmt'
    and networks.description ~*
      (select name from datacenters where datacenter_id = $1)
$_$
    LANGUAGE sql;


ALTER FUNCTION cnu_net.datacenter_mgmt_network_id(integer) OWNER TO cnu_it_config;

--
-- Name: get_protocol(text); Type: FUNCTION; Schema: cnu_net; Owner: cnu_it_config
--

CREATE FUNCTION get_protocol(text) RETURNS integer
    AS $_$ select protocol_id from protocols where proto = $1; $_$
    LANGUAGE sql;


ALTER FUNCTION cnu_net.get_protocol(text) OWNER TO cnu_it_config;

--
-- Name: is_pdu(integer); Type: FUNCTION; Schema: cnu_net; Owner: cnu_it_config
--

CREATE FUNCTION is_pdu(integer) RETURNS boolean
    AS $_$
  select cnu_net.is_node_type($1, 'pdu') ;
$_$
    LANGUAGE sql;


ALTER FUNCTION cnu_net.is_pdu(integer) OWNER TO cnu_it_config;

--
-- Name: move_guest(text, text); Type: FUNCTION; Schema: cnu_net; Owner: cnu_it_config
--

CREATE FUNCTION move_guest(i_guest text, i_host text) RETURNS integer
    AS $$
DECLARE
--  p_host int;
 p_guest int;
BEGIN
  select into p_guest node_id from cnu_net.nodes where hostname = i_guest;
  perform cnu_net.remove_guest(p_guest) ;
  return cnu_net.add_guest(i_host, i_guest) ;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION cnu_net.move_guest(i_guest text, i_host text) OWNER TO cnu_it_config;

--
-- Name: network_type(text); Type: FUNCTION; Schema: cnu_net; Owner: cnu_it_config
--

CREATE FUNCTION network_type(text) RETURNS integer
    AS $_$
select network_type_id from network_types where name = $1;
$_$
    LANGUAGE sql;


ALTER FUNCTION cnu_net.network_type(text) OWNER TO cnu_it_config;

--
-- Name: next_cluster_ip_address(integer); Type: FUNCTION; Schema: cnu_net; Owner: cnu_it_config
--

CREATE FUNCTION next_cluster_ip_address(p_cluster_id integer) RETURNS inet
    AS $$
DECLARE
  last_ip cnu_net.cluster_nodes.ip_address%TYPE;
  -- ip_range cnu_net.clusters.ip_range%TYPE;
  rec record;
  max_ip inet;
  next_ip inet;
  netmask_length int;
BEGIN
  select into rec * from clusters where cluster_id = p_cluster_id ;
  select into last_ip inet(host(ip_address)) from cluster_nodes
          where ip_address <<= rec.ip_range order by 1 desc limit 1;
  -- the latest ip used,if none start at .20
  last_ip        := coalesce(last_ip, inet(rec.ip_range)+20);
  --  this is complicated as the netmask as well as address are compared 
  netmask_length := masklen(rec.ip_range);
  max_ip         := broadcast(rec.ip_range);
  -- force netmask to match ip_range
  next_ip        := set_masklen(last_ip + 1, netmask_length) ;
  if max_ip <= next_ip then
    raise exception 'No more addresses in cluster: %', rec.cluster_name;
    return NULL;
  end if;
  -- raise notice 'New IP: % for cluster %', next_ip, rec.cluster_name;
  return next_ip;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION cnu_net.next_cluster_ip_address(p_cluster_id integer) OWNER TO cnu_it_config;

--
-- Name: next_network_ip_address(integer); Type: FUNCTION; Schema: cnu_net; Owner: cnu_it_config
--

CREATE FUNCTION next_network_ip_address(p_network_id integer) RETURNS inet
    AS $$
DECLARE
  next_ip inet;
  netrange cidr;
BEGIN
  select into netrange ip_range from networks where network_id = p_network_id;
  select into next_ip * from all_ip_addresses(netrange, 20) except (
      select ip_address from ip_addresses 
        where network_id = p_network_id or ip_address <<= netrange
  ) order by 1 limit 1;
  if next_ip is null then -- max_ip <= next_ip then
    raise exception 'No more addresses in network: %', netrange ;
    return NULL;
  end if;
  return next_ip;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION cnu_net.next_network_ip_address(p_network_id integer) OWNER TO cnu_it_config;

--
-- Name: remove_guest(integer); Type: FUNCTION; Schema: cnu_net; Owner: cnu_it_config
--

CREATE FUNCTION remove_guest(p_guest integer) RETURNS void
    AS $$
BEGIN
  perform assert(is_guest(p_guest), 'not a guest: '|| p_guest);
  delete from cnu_net.xen_mappings where guest_id = p_guest;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION cnu_net.remove_guest(p_guest integer) OWNER TO cnu_it_config;

--
-- Name: san_next_ip_address(integer); Type: FUNCTION; Schema: cnu_net; Owner: cnu_it_config
--

CREATE FUNCTION san_next_ip_address(san integer) RETURNS inet
    AS $$
DECLARE
  last_ip cnu_net.san_nodes.ip_address%TYPE;
  san_ip_range cnu_net.sans.ip_range%TYPE;
BEGIN
  select into san_ip_range ip_range from sans where san_id = san;
  select into last_ip ip_address from san_nodes where san_id = san order by ip_address desc limit 1; 
  last_ip := coalesce(last_ip, inet(san_ip_range)+99);
  if broadcast(last_ip) <= last_ip + 1 then
    raise exception 'No more addresses in san: %', san;
  end if;
  -- raise notice 'New IP: % for san %', last_ip+1, san;
  return last_ip + 1;
END;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION cnu_net.san_next_ip_address(san integer) OWNER TO cnu_it_config;

--
-- Name: trigger_created_at(); Type: FUNCTION; Schema: cnu_net; Owner: cnu_it_config
--

CREATE FUNCTION trigger_created_at() RETURNS trigger
    AS $$
  begin
    NEW.created_at := now();
    NEW.updated_at := now();
    RETURN NEW;
  end;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION cnu_net.trigger_created_at() OWNER TO cnu_it_config;

--
-- Name: trigger_updated_at(); Type: FUNCTION; Schema: cnu_net; Owner: cnu_it_config
--

CREATE FUNCTION trigger_updated_at() RETURNS trigger
    AS $$
  begin
    NEW.created_at := OLD.created_at;
    NEW.updated_at := now();
    RETURN NEW;
  end;
$$
    LANGUAGE plpgsql;


ALTER FUNCTION cnu_net.trigger_updated_at() OWNER TO cnu_it_config;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: acls; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE acls (
    acl_id integer NOT NULL,
    source cidr DEFAULT '0.0.0.0/0'::cidr NOT NULL,
    destination integer,
    port_id integer NOT NULL,
    permit boolean DEFAULT true
);


ALTER TABLE cnu_net.acls OWNER TO cnu_it_config;

--
-- Name: TABLE acls; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON TABLE acls IS 'access control list entries';


--
-- Name: COLUMN acls.destination; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON COLUMN acls.destination IS ' null means any ';


--
-- Name: acls_acl_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE acls_acl_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.acls_acl_id_seq OWNER TO cnu_it_config;

--
-- Name: acls_acl_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE acls_acl_id_seq OWNED BY acls.acl_id;


--
-- Name: cluster_nodes; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE cluster_nodes (
    cluster_id integer NOT NULL,
    node_id integer NOT NULL,
    ip_address inet
);


ALTER TABLE cnu_net.cluster_nodes OWNER TO cnu_it_config;

--
-- Name: nics; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE nics (
    nic_id integer NOT NULL,
    port_name text,
    network_type text,
    mac_address macaddr
);


ALTER TABLE cnu_net.nics OWNER TO cnu_it_config;

--
-- Name: node_nics; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE node_nics (
    node_id integer NOT NULL,
    nic_id integer NOT NULL
);


ALTER TABLE cnu_net.node_nics OWNER TO cnu_it_config;

--
-- Name: node_type; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE node_type (
    node_type_id integer NOT NULL,
    node_type text
);


ALTER TABLE cnu_net.node_type OWNER TO cnu_it_config;

--
-- Name: nodes; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE nodes (
    node_id integer NOT NULL,
    serial_no text,
    model_id integer,
    node_type_id integer,
    location_id integer,
    serial_console text,
    mgmt_ip_address_old text,
    hostname text,
    os_version_id integer,
    datacenter_id integer NOT NULL,
    service_tag text,
    mgmt_ip_address_id integer
);


ALTER TABLE cnu_net.nodes OWNER TO cnu_it_config;

--
-- Name: COLUMN nodes.mgmt_ip_address_id; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON COLUMN nodes.mgmt_ip_address_id IS 'mgmt ip_address reference';


--
-- Name: available_nodes; Type: VIEW; Schema: cnu_net; Owner: cnu_it_config
--

CREATE VIEW available_nodes AS
    SELECT cn.ip_address AS node_ip, n.node_id AS id, n.hostname AS host, n.mgmt_ip_address_old AS mgmt, nics.mac_address, nics.port_name AS nic, nics.network_type FROM ((((nodes n LEFT JOIN cluster_nodes cn ON ((n.node_id = cn.node_id))) JOIN node_type nt ON ((n.node_type_id = nt.node_type_id))) JOIN node_nics nn ON ((n.node_id = nn.node_id))) JOIN nics ON ((nics.nic_id = nn.nic_id))) WHERE (nt.node_type <> 'dummy'::text);


ALTER TABLE cnu_net.available_nodes OWNER TO cnu_it_config;

--
-- Name: bootstraps; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE bootstraps (
    id integer NOT NULL,
    node_id integer,
    model_id integer,
    dmesg text,
    dmidecode text,
    proc_meminfo text,
    proc_cpuinfo text,
    service_tag text,
    uuid_tag text,
    product_name text,
    on_fire boolean DEFAULT false NOT NULL,
    stage_one boolean DEFAULT false NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    stage_two boolean DEFAULT false NOT NULL,
    memory integer,
    nics text,
    ip text
);


ALTER TABLE cnu_net.bootstraps OWNER TO cnu_it_config;

--
-- Name: TABLE bootstraps; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON TABLE bootstraps IS 'initial data gathered from a fresh node to bootstrap and';


--
-- Name: COLUMN bootstraps.dmesg; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON COLUMN bootstraps.dmesg IS 'output from dmesg command';


--
-- Name: COLUMN bootstraps.dmidecode; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON COLUMN bootstraps.dmidecode IS 'output from dmidecode command';


--
-- Name: COLUMN bootstraps.proc_meminfo; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON COLUMN bootstraps.proc_meminfo IS 'contents of /proc/meminfo';


--
-- Name: COLUMN bootstraps.proc_cpuinfo; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON COLUMN bootstraps.proc_cpuinfo IS 'contents of /proc/cpuinfo';


--
-- Name: bootstraps_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE bootstraps_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.bootstraps_id_seq OWNER TO cnu_it_config;

--
-- Name: bootstraps_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE bootstraps_id_seq OWNED BY bootstraps.id;


--
-- Name: cluster_services; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE cluster_services (
    cluster_id integer NOT NULL,
    service_id integer NOT NULL
);


ALTER TABLE cnu_net.cluster_services OWNER TO cnu_it_config;

--
-- Name: clusters; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE clusters (
    cluster_id integer NOT NULL,
    cluster_name character varying(16),
    description text,
    vlan integer,
    ip_range cidr,
    fw_mark integer,
    load_balanced boolean DEFAULT true
);


ALTER TABLE cnu_net.clusters OWNER TO cnu_it_config;

--
-- Name: protocols; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE protocols (
    protocol_id integer NOT NULL,
    proto character(4)
);


ALTER TABLE cnu_net.protocols OWNER TO cnu_it_config;

--
-- Name: services; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE services (
    service_id integer NOT NULL,
    name text,
    description text,
    url text,
    ip_address text,
    service_port integer,
    availability text,
    check_url text,
    check_port integer,
    trending_url text,
    glb_availablilty text,
    protocol_id integer DEFAULT 1,
    local_port integer,
    not_unique integer DEFAULT 1
);


ALTER TABLE cnu_net.services OWNER TO cnu_it_config;

--
-- Name: cluster_configurations; Type: VIEW; Schema: cnu_net; Owner: cnu_it_config
--

CREATE VIEW cluster_configurations AS
    SELECT c.cluster_name AS c, c.vlan, c.ip_range, s.name, c.fw_mark, s.url, s.ip_address AS ha_ip_address, s.service_port AS port, s.local_port, s.availability AS area, cn.ip_address AS node_ip, n.hostname AS host, n.mgmt_ip_address_old AS mgmt, p.proto, n.node_id, c.load_balanced AS is_lb FROM (((((services s JOIN cluster_services cs ON ((s.service_id = cs.service_id))) JOIN clusters c ON ((c.cluster_id = cs.cluster_id))) JOIN cluster_nodes cn ON ((c.cluster_id = cn.cluster_id))) JOIN nodes n ON ((n.node_id = cn.node_id))) JOIN protocols p ON ((p.protocol_id = s.protocol_id)));


ALTER TABLE cnu_net.cluster_configurations OWNER TO cnu_it_config;

--
-- Name: cluster_configurations2; Type: VIEW; Schema: cnu_net; Owner: cnu_it_config
--

CREATE VIEW cluster_configurations2 AS
    SELECT c.cluster_name AS c, c.vlan, c.ip_range, s.name, c.fw_mark, s.url, s.ip_address AS ha_ip_address, s.service_port AS port, s.availability AS area, cn.ip_address AS node_ip, n.hostname AS host, n.mgmt_ip_address_old AS mgmt, nics.mac_address, nics.port_name AS nic, p.proto FROM (((((((services s JOIN cluster_services cs ON ((s.service_id = cs.service_id))) JOIN clusters c ON ((c.cluster_id = cs.cluster_id))) JOIN cluster_nodes cn ON ((c.cluster_id = cn.cluster_id))) JOIN nodes n ON ((n.node_id = cn.node_id))) JOIN node_nics nn ON ((n.node_id = nn.node_id))) JOIN nics ON ((nics.nic_id = nn.nic_id))) JOIN protocols p ON ((p.protocol_id = s.protocol_id)));


ALTER TABLE cnu_net.cluster_configurations2 OWNER TO cnu_it_config;

--
-- Name: clusters_cluster_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE clusters_cluster_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.clusters_cluster_id_seq OWNER TO cnu_it_config;

--
-- Name: clusters_cluster_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE clusters_cluster_id_seq OWNED BY clusters.cluster_id;


--
-- Name: cnu_machine_models; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE cnu_machine_models (
    model_id integer NOT NULL,
    megabytes_memory integer,
    power_supplies integer,
    cpu_cores integer,
    cpu_speed_megahertz integer,
    network_interfaces integer,
    model_no text,
    manufacturer text,
    max_amps_used integer,
    max_btu_per_hour integer,
    serial_console_type text,
    rack_size integer,
    serial_baud_rate integer,
    serial_dce_dte boolean DEFAULT true NOT NULL,
    serial_flow_control text DEFAULT 'none'::text,
    CONSTRAINT cnu_machine_models_serial_flow_control_check CHECK ((serial_flow_control = ANY (ARRAY['none'::text, 'software'::text, 'hardware'::text])))
);


ALTER TABLE cnu_net.cnu_machine_models OWNER TO cnu_it_config;

--
-- Name: COLUMN cnu_machine_models.serial_dce_dte; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON COLUMN cnu_machine_models.serial_dce_dte IS 'True for DCE false for DTE';


--
-- Name: COLUMN cnu_machine_models.serial_flow_control; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON COLUMN cnu_machine_models.serial_flow_control IS 'None: no flow control, hardware or software';


--
-- Name: cnu_machine_models_model_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE cnu_machine_models_model_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.cnu_machine_models_model_id_seq OWNER TO cnu_it_config;

--
-- Name: cnu_machine_models_model_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE cnu_machine_models_model_id_seq OWNED BY cnu_machine_models.model_id;


--
-- Name: database_accesses; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE database_accesses (
    database_access_id integer NOT NULL,
    node_id integer,
    network_id integer,
    inet_addr inet,
    allow boolean,
    auth_method text,
    rolename text DEFAULT 'all'::text NOT NULL,
    CONSTRAINT database_accesses_check CHECK (((((node_id IS NOT NULL) OR (network_id IS NOT NULL)) OR (inet_addr IS NOT NULL)) AND ((((node_id IS NULL) AND (network_id IS NOT NULL)) OR ((node_id IS NOT NULL) AND (network_id IS NULL))) OR ((node_id IS NULL) AND (network_id IS NULL)))))
);


ALTER TABLE cnu_net.database_accesses OWNER TO cnu_it_config;

--
-- Name: TABLE database_accesses; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON TABLE database_accesses IS 'order is first match. This continues the default postgres access policy of deny.';


--
-- Name: COLUMN database_accesses.allow; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON COLUMN database_accesses.allow IS 'allow access or a deny if false.';


--
-- Name: COLUMN database_accesses.rolename; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON COLUMN database_accesses.rolename IS 'username which access applies.';


--
-- Name: database_accesses_database_access_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE database_accesses_database_access_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.database_accesses_database_access_id_seq OWNER TO cnu_it_config;

--
-- Name: database_accesses_database_access_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE database_accesses_database_access_id_seq OWNED BY database_accesses.database_access_id;


--
-- Name: database_acls; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE database_acls (
    database_acl_id integer NOT NULL,
    database_access_id integer NOT NULL,
    database_cluster_id integer NOT NULL,
    database_name_id integer,
    "position" integer,
    CONSTRAINT database_acls_position_check CHECK (("position" > 0))
);


ALTER TABLE cnu_net.database_acls OWNER TO cnu_it_config;

--
-- Name: COLUMN database_acls.database_name_id; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON COLUMN database_acls.database_name_id IS ' null is "all" for pg_hba';


--
-- Name: COLUMN database_acls."position"; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON COLUMN database_acls."position" IS 'list position';


--
-- Name: database_acls_database_acl_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE database_acls_database_acl_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.database_acls_database_acl_id_seq OWNER TO cnu_it_config;

--
-- Name: database_acls_database_acl_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE database_acls_database_acl_id_seq OWNED BY database_acls.database_acl_id;


--
-- Name: database_auth_methods; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE database_auth_methods (
    auth_method text NOT NULL
);


ALTER TABLE cnu_net.database_auth_methods OWNER TO cnu_it_config;

--
-- Name: TABLE database_auth_methods; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON TABLE database_auth_methods IS 'list of accessbile auth/access
methods based on policy. It is not a complete list of postgres supported
methods.';


--
-- Name: database_cluster_database_names; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE database_cluster_database_names (
    database_cluster_id integer NOT NULL,
    database_name_id integer NOT NULL
);


ALTER TABLE cnu_net.database_cluster_database_names OWNER TO cnu_it_config;

--
-- Name: database_clusters; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE database_clusters (
    database_cluster_id integer NOT NULL,
    name character varying(16),
    version numeric(3,1),
    description text,
    service_id integer,
    database_config_id integer,
    archive boolean DEFAULT false NOT NULL
);


ALTER TABLE cnu_net.database_clusters OWNER TO cnu_it_config;

--
-- Name: COLUMN database_clusters.name; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON COLUMN database_clusters.name IS 'name as shown in database_lsclusters';


--
-- Name: database_clusters_database_cluster_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE database_clusters_database_cluster_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.database_clusters_database_cluster_id_seq OWNER TO cnu_it_config;

--
-- Name: database_clusters_database_cluster_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE database_clusters_database_cluster_id_seq OWNED BY database_clusters.database_cluster_id;


--
-- Name: database_configs; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE database_configs (
    database_config_id integer NOT NULL,
    name text,
    max_connections integer,
    port integer,
    disk_size text,
    work_mem text,
    maintenance_mem text,
    shared_buffers text,
    temp_buffers text,
    effective_cache_size text,
    search_path text,
    timezone text,
    log_min_duration_statement text,
    max_fsm_pages integer,
    vacuum_cost_delay integer DEFAULT 10,
    wal_buffers text DEFAULT '1MB'::text,
    timezone_abbreviations text DEFAULT 'Default'::text,
    bgwriter_lru_maxpages integer DEFAULT 100,
    bgwriter_delay text DEFAULT '200ms'::text,
    bgwriter_lru_multiplier numeric(3,1) DEFAULT 10.0,
    checkpoint_segments integer DEFAULT 100,
    random_page_cost numeric(3,2) DEFAULT 2.0
);


ALTER TABLE cnu_net.database_configs OWNER TO cnu_it_config;

--
-- Name: database_configs_database_config_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE database_configs_database_config_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.database_configs_database_config_id_seq OWNER TO cnu_it_config;

--
-- Name: database_configs_database_config_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE database_configs_database_config_id_seq OWNED BY database_configs.database_config_id;


--
-- Name: database_names; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE database_names (
    database_name_id integer NOT NULL,
    name name,
    description text
);


ALTER TABLE cnu_net.database_names OWNER TO cnu_it_config;

--
-- Name: database_names_database_name_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE database_names_database_name_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.database_names_database_name_id_seq OWNER TO cnu_it_config;

--
-- Name: database_names_database_name_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE database_names_database_name_id_seq OWNED BY database_names.database_name_id;


--
-- Name: database_versions; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE database_versions (
    id integer NOT NULL,
    version numeric(3,1),
    CONSTRAINT database_versions_version_check CHECK ((version > 8.2))
);


ALTER TABLE cnu_net.database_versions OWNER TO cnu_it_config;

--
-- Name: database_versions_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE database_versions_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.database_versions_id_seq OWNER TO cnu_it_config;

--
-- Name: database_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE database_versions_id_seq OWNED BY database_versions.id;


--
-- Name: datacenters; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE datacenters (
    datacenter_id integer NOT NULL,
    name text,
    active boolean DEFAULT false
);


ALTER TABLE cnu_net.datacenters OWNER TO cnu_it_config;

--
-- Name: datacenters_datacenter_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE datacenters_datacenter_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.datacenters_datacenter_id_seq OWNER TO cnu_it_config;

--
-- Name: datacenters_datacenter_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE datacenters_datacenter_id_seq OWNED BY datacenters.datacenter_id;


--
-- Name: disk_types; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE disk_types (
    id integer NOT NULL,
    disk_type text
);


ALTER TABLE cnu_net.disk_types OWNER TO cnu_it_config;

--
-- Name: disk_types_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE disk_types_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.disk_types_id_seq OWNER TO cnu_it_config;

--
-- Name: disk_types_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE disk_types_id_seq OWNED BY disk_types.id;


--
-- Name: disks; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE disks (
    disk_id integer NOT NULL,
    total_megabytes integer,
    mount_point text,
    sparse boolean DEFAULT false,
    name text NOT NULL,
    disk_type text NOT NULL,
    block_name text,
    filesystem text DEFAULT 'ext3'::text,
    read_only boolean DEFAULT false,
    mount_options text
);


ALTER TABLE cnu_net.disks OWNER TO cnu_it_config;

--
-- Name: disks_disk_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE disks_disk_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.disks_disk_id_seq OWNER TO cnu_it_config;

--
-- Name: disks_disk_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE disks_disk_id_seq OWNED BY disks.disk_id;


--
-- Name: distributions; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE distributions (
    id integer NOT NULL,
    name text
);


ALTER TABLE cnu_net.distributions OWNER TO cnu_it_config;

--
-- Name: distributions_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE distributions_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.distributions_id_seq OWNER TO cnu_it_config;

--
-- Name: distributions_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE distributions_id_seq OWNED BY distributions.id;


--
-- Name: host_macs; Type: VIEW; Schema: cnu_net; Owner: cnu_it_config
--

CREATE VIEW host_macs AS
    SELECT nic.nic_id, nic.network_type AS type, nic.mac_address, ((n.hostname || '.'::text) || datacenters.name) AS hostname, n.node_id, n.serial_no FROM (((nodes n JOIN datacenters USING (datacenter_id)) JOIN node_nics USING (node_id)) JOIN nics nic USING (nic_id));


ALTER TABLE cnu_net.host_macs OWNER TO cnu_it_config;

--
-- Name: ip_addresses; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE ip_addresses (
    ip_address_id integer NOT NULL,
    network_id integer,
    ip_address inet,
    default_network boolean DEFAULT false,
    non_unique integer DEFAULT 0
);


ALTER TABLE cnu_net.ip_addresses OWNER TO cnu_it_config;

--
-- Name: ip_addresses_ip_address_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE ip_addresses_ip_address_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.ip_addresses_ip_address_id_seq OWNER TO cnu_it_config;

--
-- Name: ip_addresses_ip_address_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE ip_addresses_ip_address_id_seq OWNED BY ip_addresses.ip_address_id;


--
-- Name: ip_ports; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE ip_ports (
    port_id integer NOT NULL,
    port integer,
    protocol_id integer,
    uri_schema text NOT NULL,
    description text
);


ALTER TABLE cnu_net.ip_ports OWNER TO cnu_it_config;

--
-- Name: TABLE ip_ports; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON TABLE ip_ports IS 'canonical internet protocol ports';


--
-- Name: ip_ports_port_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE ip_ports_port_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.ip_ports_port_id_seq OWNER TO cnu_it_config;

--
-- Name: ip_ports_port_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE ip_ports_port_id_seq OWNED BY ip_ports.port_id;


--
-- Name: live_xen_maps; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE live_xen_maps (
    live_xen_map_id integer NOT NULL,
    host_id integer NOT NULL,
    client_id integer,
    client_name text,
    CONSTRAINT live_xen_maps_check CHECK (((client_name IS NOT NULL) OR (client_id IS NOT NULL))),
    CONSTRAINT live_xen_maps_check1 CHECK ((client_id <> host_id))
);


ALTER TABLE cnu_net.live_xen_maps OWNER TO cnu_it_config;

--
-- Name: live_xen_maps_live_xen_map_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE live_xen_maps_live_xen_map_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.live_xen_maps_live_xen_map_id_seq OWNER TO cnu_it_config;

--
-- Name: live_xen_maps_live_xen_map_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE live_xen_maps_live_xen_map_id_seq OWNED BY live_xen_maps.live_xen_map_id;


--
-- Name: locations; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE locations (
    location_id integer NOT NULL,
    datacenter_id integer,
    rack integer,
    rack_position_bottom integer,
    rack_position_top integer
);


ALTER TABLE cnu_net.locations OWNER TO cnu_it_config;

--
-- Name: location_nodes; Type: VIEW; Schema: cnu_net; Owner: cnu_it_config
--

CREATE VIEW location_nodes AS
    SELECT n.node_id, n.hostname, n.mgmt_ip_address_old AS mgmt_ip_address, dc.name AS loc, nt.node_type FROM (((nodes n JOIN node_type nt ON ((n.node_type_id = nt.node_type_id))) JOIN locations l ON ((n.location_id = l.location_id))) JOIN datacenters dc ON ((l.datacenter_id = dc.datacenter_id))) WHERE (nt.node_type <> 'dummy'::text) ORDER BY (host((n.mgmt_ip_address_old)::inet))::inet;


ALTER TABLE cnu_net.location_nodes OWNER TO cnu_it_config;

--
-- Name: locations_location_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE locations_location_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.locations_location_id_seq OWNER TO cnu_it_config;

--
-- Name: locations_location_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE locations_location_id_seq OWNED BY locations.location_id;


--
-- Name: network_acls; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE network_acls (
    id integer NOT NULL,
    acl_id integer NOT NULL,
    network_id integer NOT NULL
);


ALTER TABLE cnu_net.network_acls OWNER TO cnu_it_config;

--
-- Name: TABLE network_acls; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON TABLE network_acls IS 'sets of acls for a network, has_many';


--
-- Name: network_acls_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE network_acls_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.network_acls_id_seq OWNER TO cnu_it_config;

--
-- Name: network_acls_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE network_acls_id_seq OWNED BY network_acls.id;


--
-- Name: network_switch_ports; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE network_switch_ports (
    id integer NOT NULL,
    node_id integer NOT NULL,
    switch_id integer NOT NULL,
    port character varying(10) NOT NULL,
    CONSTRAINT network_switch_ports_check CHECK ((node_id <> switch_id))
);


ALTER TABLE cnu_net.network_switch_ports OWNER TO cnu_it_config;

--
-- Name: network_switch_ports_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE network_switch_ports_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.network_switch_ports_id_seq OWNER TO cnu_it_config;

--
-- Name: network_switch_ports_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE network_switch_ports_id_seq OWNED BY network_switch_ports.id;


--
-- Name: network_types; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE network_types (
    network_type_id integer NOT NULL,
    name text
);


ALTER TABLE cnu_net.network_types OWNER TO cnu_it_config;

--
-- Name: network_types_network_type_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE network_types_network_type_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.network_types_network_type_id_seq OWNER TO cnu_it_config;

--
-- Name: network_types_network_type_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE network_types_network_type_id_seq OWNED BY network_types.network_type_id;


--
-- Name: networks; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE networks (
    network_id integer NOT NULL,
    description text,
    vlan smallint NOT NULL,
    ip_range cidr NOT NULL,
    network_gateway inet,
    network_type_id integer,
    CONSTRAINT networks_check CHECK (((network_gateway IS NULL) OR (network_gateway <<= (ip_range)::inet))),
    CONSTRAINT networks_vlan_check CHECK (((vlan > 0) AND (vlan <= 4096)))
);


ALTER TABLE cnu_net.networks OWNER TO cnu_it_config;

--
-- Name: networks_network_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE networks_network_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.networks_network_id_seq OWNER TO cnu_it_config;

--
-- Name: networks_network_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE networks_network_id_seq OWNED BY networks.network_id;


--
-- Name: nics_nic_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE nics_nic_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.nics_nic_id_seq OWNER TO cnu_it_config;

--
-- Name: nics_nic_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE nics_nic_id_seq OWNED BY nics.nic_id;


--
-- Name: node_acls; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE node_acls (
    acl_id integer NOT NULL,
    node_id integer NOT NULL
);


ALTER TABLE cnu_net.node_acls OWNER TO cnu_it_config;

--
-- Name: TABLE node_acls; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON TABLE node_acls IS 'sets of acls for a node, has_many';


--
-- Name: node_disks; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE node_disks (
    node_id integer NOT NULL,
    disk_id integer NOT NULL,
    id integer NOT NULL,
    block_name text
);


ALTER TABLE cnu_net.node_disks OWNER TO cnu_it_config;

--
-- Name: node_disks_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE node_disks_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.node_disks_id_seq OWNER TO cnu_it_config;

--
-- Name: node_disks_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE node_disks_id_seq OWNED BY node_disks.id;


--
-- Name: node_type_node_type_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE node_type_node_type_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.node_type_node_type_id_seq OWNER TO cnu_it_config;

--
-- Name: node_type_node_type_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE node_type_node_type_id_seq OWNED BY node_type.node_type_id;


--
-- Name: nodes_node_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE nodes_node_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.nodes_node_id_seq OWNER TO cnu_it_config;

--
-- Name: nodes_node_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE nodes_node_id_seq OWNED BY nodes.node_id;


--
-- Name: os_versions; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE os_versions (
    id integer NOT NULL,
    description text,
    distribution text,
    kernel text
);


ALTER TABLE cnu_net.os_versions OWNER TO cnu_it_config;

--
-- Name: os_versions_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE os_versions_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.os_versions_id_seq OWNER TO cnu_it_config;

--
-- Name: os_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE os_versions_id_seq OWNED BY os_versions.id;


--
-- Name: pdus; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE pdus (
    id integer NOT NULL,
    node_id integer,
    pdu_id integer,
    outlet_no smallint,
    CONSTRAINT pdus_check CHECK ((node_id <> pdu_id)),
    CONSTRAINT pdus_outlet_no_check CHECK (((outlet_no > 0) AND (outlet_no < 50)))
);


ALTER TABLE cnu_net.pdus OWNER TO cnu_it_config;

--
-- Name: pdus_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE pdus_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.pdus_id_seq OWNER TO cnu_it_config;

--
-- Name: pdus_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE pdus_id_seq OWNED BY pdus.id;


--
-- Name: policies; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE policies (
    policy_id integer NOT NULL,
    name text NOT NULL,
    permit boolean NOT NULL,
    policy_object_type text,
    object_type_id integer,
    CONSTRAINT policies_policy_object_type_check CHECK ((policy_object_type = ANY (ARRAY['NetworkType'::text, 'NodeType'::text])))
);


ALTER TABLE cnu_net.policies OWNER TO cnu_it_config;

--
-- Name: TABLE policies; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON TABLE policies IS 'predefined groups of acl entries';


--
-- Name: policies_policy_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE policies_policy_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.policies_policy_id_seq OWNER TO cnu_it_config;

--
-- Name: policies_policy_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE policies_policy_id_seq OWNED BY policies.policy_id;


--
-- Name: policy_acls; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE policy_acls (
    id integer NOT NULL,
    policy_id integer NOT NULL,
    acl_id integer NOT NULL
);


ALTER TABLE cnu_net.policy_acls OWNER TO cnu_it_config;

--
-- Name: TABLE policy_acls; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON TABLE policy_acls IS 'sets of acls for a policy, has_many';


--
-- Name: COLUMN policy_acls.id; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON COLUMN policy_acls.id IS ' a surrogate key for RoRails to ''work''';


--
-- Name: policy_acls_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE policy_acls_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.policy_acls_id_seq OWNER TO cnu_it_config;

--
-- Name: policy_acls_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE policy_acls_id_seq OWNED BY policy_acls.id;


--
-- Name: protocols_protocol_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE protocols_protocol_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.protocols_protocol_id_seq OWNER TO cnu_it_config;

--
-- Name: protocols_protocol_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE protocols_protocol_id_seq OWNED BY protocols.protocol_id;


--
-- Name: rampart_service_templates; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE rampart_service_templates (
    id integer NOT NULL,
    description text NOT NULL,
    network cidr NOT NULL,
    port integer,
    protocol text NOT NULL,
    direction text NOT NULL,
    CONSTRAINT rampart_service_templates_port_check CHECK (((port > 0) AND (port < 65536))),
    CONSTRAINT rampart_service_templates_protocol_check CHECK ((protocol = ANY (ARRAY['tcp'::text, 'udp'::text, 'icmp'::text, 'all'::text])))
);


ALTER TABLE cnu_net.rampart_service_templates OWNER TO cnu_it_config;

--
-- Name: TABLE rampart_service_templates; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON TABLE rampart_service_templates IS ' Template for creating new
Rampart services ';


--
-- Name: COLUMN rampart_service_templates.direction; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON COLUMN rampart_service_templates.direction IS ' direction in ''in'', ''out''';


--
-- Name: rampart_service_templates_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE rampart_service_templates_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.rampart_service_templates_id_seq OWNER TO cnu_it_config;

--
-- Name: rampart_service_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE rampart_service_templates_id_seq OWNED BY rampart_service_templates.id;


--
-- Name: rampart_services; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE rampart_services (
    id integer NOT NULL,
    rampart_id integer,
    network cidr,
    port integer,
    protocol text,
    direction text,
    description text
);


ALTER TABLE cnu_net.rampart_services OWNER TO cnu_it_config;

--
-- Name: COLUMN rampart_services.protocol; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON COLUMN rampart_services.protocol IS ' protocol in ''all'', ''tcp'', ''udp'', ''icmp''';


--
-- Name: COLUMN rampart_services.direction; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON COLUMN rampart_services.direction IS ' direction in ''in'', ''out''';


--
-- Name: rampart_services_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE rampart_services_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.rampart_services_id_seq OWNER TO cnu_it_config;

--
-- Name: rampart_services_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE rampart_services_id_seq OWNED BY rampart_services.id;


--
-- Name: ramparts; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE ramparts (
    id integer NOT NULL,
    node_id integer,
    has_public_ip boolean DEFAULT false NOT NULL,
    has_service_ip boolean DEFAULT false NOT NULL,
    home_network text,
    locale_ip_old inet,
    network_ip inet,
    public_ip_old inet,
    public_ip_address_id integer,
    locale_ip_address_id integer
);


ALTER TABLE cnu_net.ramparts OWNER TO cnu_it_config;

--
-- Name: TABLE ramparts; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON TABLE ramparts IS 'used to manage vallation box';


--
-- Name: COLUMN ramparts.home_network; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON COLUMN ramparts.home_network IS ' home_network in ''prod'', ''dev'', ''bi'', ''qa''';


--
-- Name: ramparts_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE ramparts_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.ramparts_id_seq OWNER TO cnu_it_config;

--
-- Name: ramparts_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE ramparts_id_seq OWNED BY ramparts.id;


--
-- Name: roles; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE roles (
    role_id integer NOT NULL,
    name text,
    description text,
    grant_select boolean,
    grant_update boolean,
    grant_delete boolean,
    grant_create boolean,
    grant_insert boolean
);


ALTER TABLE cnu_net.roles OWNER TO cnu_it_config;

--
-- Name: roles_role_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE roles_role_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.roles_role_id_seq OWNER TO cnu_it_config;

--
-- Name: roles_role_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE roles_role_id_seq OWNED BY roles.role_id;


--
-- Name: san_nodes; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE san_nodes (
    san_id integer NOT NULL,
    node_id integer NOT NULL,
    ip_address_old inet,
    ip_address_id integer NOT NULL
);


ALTER TABLE cnu_net.san_nodes OWNER TO cnu_it_config;

--
-- Name: sans; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE sans (
    san_id integer NOT NULL,
    san_name character varying(16),
    description text,
    ip_range_old cidr,
    vlan_old integer,
    network_id integer NOT NULL
);


ALTER TABLE cnu_net.sans OWNER TO cnu_it_config;

--
-- Name: sans_san_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE sans_san_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.sans_san_id_seq OWNER TO cnu_it_config;

--
-- Name: sans_san_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE sans_san_id_seq OWNED BY sans.san_id;


--
-- Name: serial_baud_rates; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE serial_baud_rates (
    speed integer NOT NULL
);


ALTER TABLE cnu_net.serial_baud_rates OWNER TO cnu_it_config;

--
-- Name: TABLE serial_baud_rates; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON TABLE serial_baud_rates IS 'Lookup code table for serial baud rates to help prevent invalid values';


--
-- Name: serial_consoles; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE serial_consoles (
    id integer NOT NULL,
    node_id integer,
    scs_id integer,
    port smallint,
    CONSTRAINT serial_consoles_check CHECK ((node_id <> scs_id)),
    CONSTRAINT serial_consoles_port_check CHECK (((port > 0) AND (port < 99)))
);


ALTER TABLE cnu_net.serial_consoles OWNER TO cnu_it_config;

--
-- Name: serial_consoles_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE serial_consoles_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.serial_consoles_id_seq OWNER TO cnu_it_config;

--
-- Name: serial_consoles_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE serial_consoles_id_seq OWNED BY serial_consoles.id;


--
-- Name: service_dependencies; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE service_dependencies (
    id integer NOT NULL,
    parent_id integer,
    child_id integer
);


ALTER TABLE cnu_net.service_dependencies OWNER TO cnu_it_config;

--
-- Name: service_dependencies_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE service_dependencies_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.service_dependencies_id_seq OWNER TO cnu_it_config;

--
-- Name: service_dependencies_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE service_dependencies_id_seq OWNED BY service_dependencies.id;


--
-- Name: service_locations; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE service_locations (
    service_id integer NOT NULL,
    datacenter_id integer NOT NULL
);


ALTER TABLE cnu_net.service_locations OWNER TO cnu_it_config;

--
-- Name: service_ports; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE service_ports (
    id integer NOT NULL,
    service_id integer NOT NULL,
    port_id integer NOT NULL,
    local_port integer,
    has_proxy integer DEFAULT 0
);


ALTER TABLE cnu_net.service_ports OWNER TO cnu_it_config;

--
-- Name: TABLE service_ports; Type: COMMENT; Schema: cnu_net; Owner: cnu_it_config
--

COMMENT ON TABLE service_ports IS 'normalized join of services and ports';


--
-- Name: service_ports_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE service_ports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.service_ports_id_seq OWNER TO cnu_it_config;

--
-- Name: service_ports_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE service_ports_id_seq OWNED BY service_ports.id;


--
-- Name: services_service_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE services_service_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.services_service_id_seq OWNER TO cnu_it_config;

--
-- Name: services_service_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE services_service_id_seq OWNED BY services.service_id;


--
-- Name: sessions; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE sessions (
    session_id text NOT NULL,
    data text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    id integer NOT NULL
);


ALTER TABLE cnu_net.sessions OWNER TO cnu_it_config;

--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE sessions_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.sessions_id_seq OWNER TO cnu_it_config;

--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE sessions_id_seq OWNED BY sessions.id;


--
-- Name: xen_mappings; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE xen_mappings (
    id integer NOT NULL,
    host_id integer NOT NULL,
    guest_id integer NOT NULL,
    CONSTRAINT xen_mappings_check CHECK ((host_id <> guest_id))
);


ALTER TABLE cnu_net.xen_mappings OWNER TO cnu_it_config;

--
-- Name: unassigned_guest_nodes; Type: VIEW; Schema: cnu_net; Owner: cnu_it_config
--

CREATE VIEW unassigned_guest_nodes AS
    SELECT a.mapped, a.node_id, a.hostname, a.mgmt_ip_address FROM (SELECT x.id AS mapped, n.node_id, n.hostname, n.mgmt_ip_address_old AS mgmt_ip_address FROM ((xen_mappings x RIGHT JOIN nodes n ON ((x.guest_id = n.node_id))) JOIN node_type nt USING (node_type_id)) WHERE (nt.node_type = 'virtual'::text)) a WHERE (a.mapped IS NULL);


ALTER TABLE cnu_net.unassigned_guest_nodes OWNER TO cnu_it_config;

--
-- Name: user_roles; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE user_roles (
    id integer NOT NULL,
    user_id integer,
    role_id integer
);


ALTER TABLE cnu_net.user_roles OWNER TO cnu_it_config;

--
-- Name: user_roles_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE user_roles_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.user_roles_id_seq OWNER TO cnu_it_config;

--
-- Name: user_roles_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE user_roles_id_seq OWNED BY user_roles.id;


--
-- Name: users; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE users (
    user_id integer NOT NULL,
    login text NOT NULL,
    name text,
    email text,
    crypted_password text,
    salt character varying(40),
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    remember_token text,
    remember_token_expires_at timestamp with time zone
);


ALTER TABLE cnu_net.users OWNER TO cnu_it_config;

--
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE users_user_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.users_user_id_seq OWNER TO cnu_it_config;

--
-- Name: users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE users_user_id_seq OWNED BY users.user_id;


--
-- Name: versions; Type: TABLE; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE TABLE versions (
    id integer NOT NULL,
    item_type character varying(255) NOT NULL,
    item_id integer NOT NULL,
    event character varying(255) NOT NULL,
    whodunnit character varying(255),
    object text,
    created_at timestamp without time zone
);


ALTER TABLE cnu_net.versions OWNER TO cnu_it_config;

--
-- Name: versions_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE versions_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.versions_id_seq OWNER TO cnu_it_config;

--
-- Name: versions_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE versions_id_seq OWNED BY versions.id;


--
-- Name: xen_mappings_id_seq; Type: SEQUENCE; Schema: cnu_net; Owner: cnu_it_config
--

CREATE SEQUENCE xen_mappings_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE cnu_net.xen_mappings_id_seq OWNER TO cnu_it_config;

--
-- Name: xen_mappings_id_seq; Type: SEQUENCE OWNED BY; Schema: cnu_net; Owner: cnu_it_config
--

ALTER SEQUENCE xen_mappings_id_seq OWNED BY xen_mappings.id;


--
-- Name: acl_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE acls ALTER COLUMN acl_id SET DEFAULT nextval('acls_acl_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE bootstraps ALTER COLUMN id SET DEFAULT nextval('bootstraps_id_seq'::regclass);


--
-- Name: cluster_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE clusters ALTER COLUMN cluster_id SET DEFAULT nextval('clusters_cluster_id_seq'::regclass);


--
-- Name: model_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE cnu_machine_models ALTER COLUMN model_id SET DEFAULT nextval('cnu_machine_models_model_id_seq'::regclass);


--
-- Name: database_access_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE database_accesses ALTER COLUMN database_access_id SET DEFAULT nextval('database_accesses_database_access_id_seq'::regclass);


--
-- Name: database_acl_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE database_acls ALTER COLUMN database_acl_id SET DEFAULT nextval('database_acls_database_acl_id_seq'::regclass);


--
-- Name: database_cluster_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE database_clusters ALTER COLUMN database_cluster_id SET DEFAULT nextval('database_clusters_database_cluster_id_seq'::regclass);


--
-- Name: database_config_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE database_configs ALTER COLUMN database_config_id SET DEFAULT nextval('database_configs_database_config_id_seq'::regclass);


--
-- Name: database_name_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE database_names ALTER COLUMN database_name_id SET DEFAULT nextval('database_names_database_name_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE database_versions ALTER COLUMN id SET DEFAULT nextval('database_versions_id_seq'::regclass);


--
-- Name: datacenter_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE datacenters ALTER COLUMN datacenter_id SET DEFAULT nextval('datacenters_datacenter_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE disk_types ALTER COLUMN id SET DEFAULT nextval('disk_types_id_seq'::regclass);


--
-- Name: disk_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE disks ALTER COLUMN disk_id SET DEFAULT nextval('disks_disk_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE distributions ALTER COLUMN id SET DEFAULT nextval('distributions_id_seq'::regclass);


--
-- Name: ip_address_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ip_addresses ALTER COLUMN ip_address_id SET DEFAULT nextval('ip_addresses_ip_address_id_seq'::regclass);


--
-- Name: port_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ip_ports ALTER COLUMN port_id SET DEFAULT nextval('ip_ports_port_id_seq'::regclass);


--
-- Name: live_xen_map_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE live_xen_maps ALTER COLUMN live_xen_map_id SET DEFAULT nextval('live_xen_maps_live_xen_map_id_seq'::regclass);


--
-- Name: location_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE locations ALTER COLUMN location_id SET DEFAULT nextval('locations_location_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE network_acls ALTER COLUMN id SET DEFAULT nextval('network_acls_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE network_switch_ports ALTER COLUMN id SET DEFAULT nextval('network_switch_ports_id_seq'::regclass);


--
-- Name: network_type_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE network_types ALTER COLUMN network_type_id SET DEFAULT nextval('network_types_network_type_id_seq'::regclass);


--
-- Name: network_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE networks ALTER COLUMN network_id SET DEFAULT nextval('networks_network_id_seq'::regclass);


--
-- Name: nic_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE nics ALTER COLUMN nic_id SET DEFAULT nextval('nics_nic_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE node_disks ALTER COLUMN id SET DEFAULT nextval('node_disks_id_seq'::regclass);


--
-- Name: node_type_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE node_type ALTER COLUMN node_type_id SET DEFAULT nextval('node_type_node_type_id_seq'::regclass);


--
-- Name: node_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE nodes ALTER COLUMN node_id SET DEFAULT nextval('nodes_node_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE os_versions ALTER COLUMN id SET DEFAULT nextval('os_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE pdus ALTER COLUMN id SET DEFAULT nextval('pdus_id_seq'::regclass);


--
-- Name: policy_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE policies ALTER COLUMN policy_id SET DEFAULT nextval('policies_policy_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE policy_acls ALTER COLUMN id SET DEFAULT nextval('policy_acls_id_seq'::regclass);


--
-- Name: protocol_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE protocols ALTER COLUMN protocol_id SET DEFAULT nextval('protocols_protocol_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE rampart_service_templates ALTER COLUMN id SET DEFAULT nextval('rampart_service_templates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE rampart_services ALTER COLUMN id SET DEFAULT nextval('rampart_services_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ramparts ALTER COLUMN id SET DEFAULT nextval('ramparts_id_seq'::regclass);


--
-- Name: role_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE roles ALTER COLUMN role_id SET DEFAULT nextval('roles_role_id_seq'::regclass);


--
-- Name: san_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE sans ALTER COLUMN san_id SET DEFAULT nextval('sans_san_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE serial_consoles ALTER COLUMN id SET DEFAULT nextval('serial_consoles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE service_dependencies ALTER COLUMN id SET DEFAULT nextval('service_dependencies_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE service_ports ALTER COLUMN id SET DEFAULT nextval('service_ports_id_seq'::regclass);


--
-- Name: service_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE services ALTER COLUMN service_id SET DEFAULT nextval('services_service_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE sessions ALTER COLUMN id SET DEFAULT nextval('sessions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE user_roles ALTER COLUMN id SET DEFAULT nextval('user_roles_id_seq'::regclass);


--
-- Name: user_id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE users ALTER COLUMN user_id SET DEFAULT nextval('users_user_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE versions ALTER COLUMN id SET DEFAULT nextval('versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE xen_mappings ALTER COLUMN id SET DEFAULT nextval('xen_mappings_id_seq'::regclass);


--
-- Name: acls_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY acls
    ADD CONSTRAINT acls_pkey PRIMARY KEY (acl_id);


--
-- Name: acls_source_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY acls
    ADD CONSTRAINT acls_source_key UNIQUE (source, port_id);


--
-- Name: bootstraps_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY bootstraps
    ADD CONSTRAINT bootstraps_pkey PRIMARY KEY (id);


--
-- Name: bootstraps_service_tag_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY bootstraps
    ADD CONSTRAINT bootstraps_service_tag_key UNIQUE (service_tag);


--
-- Name: bootstraps_uuid_tag_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY bootstraps
    ADD CONSTRAINT bootstraps_uuid_tag_key UNIQUE (uuid_tag);


--
-- Name: cluster_nodes_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY cluster_nodes
    ADD CONSTRAINT cluster_nodes_pkey PRIMARY KEY (cluster_id, node_id);


--
-- Name: cluster_services_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY cluster_services
    ADD CONSTRAINT cluster_services_pkey PRIMARY KEY (cluster_id, service_id);


--
-- Name: clusters__fw_mark__uniq; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY clusters
    ADD CONSTRAINT clusters__fw_mark__uniq UNIQUE (fw_mark);


--
-- Name: clusters_cluster_name_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY clusters
    ADD CONSTRAINT clusters_cluster_name_key UNIQUE (cluster_name);


--
-- Name: clusters_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY clusters
    ADD CONSTRAINT clusters_pkey PRIMARY KEY (cluster_id);


--
-- Name: cnu_machine_models_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY cnu_machine_models
    ADD CONSTRAINT cnu_machine_models_pkey PRIMARY KEY (model_id);


--
-- Name: database_accesses_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY database_accesses
    ADD CONSTRAINT database_accesses_pkey PRIMARY KEY (database_access_id);


--
-- Name: database_acls_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY database_acls
    ADD CONSTRAINT database_acls_pkey PRIMARY KEY (database_acl_id);


--
-- Name: database_auth_methods_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY database_auth_methods
    ADD CONSTRAINT database_auth_methods_pkey PRIMARY KEY (auth_method);


--
-- Name: database_cluster_database_names_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY database_cluster_database_names
    ADD CONSTRAINT database_cluster_database_names_pkey PRIMARY KEY (database_cluster_id, database_name_id);


--
-- Name: database_clusters_name_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY database_clusters
    ADD CONSTRAINT database_clusters_name_key UNIQUE (name);


--
-- Name: database_clusters_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY database_clusters
    ADD CONSTRAINT database_clusters_pkey PRIMARY KEY (database_cluster_id);


--
-- Name: database_clusters_service_id_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY database_clusters
    ADD CONSTRAINT database_clusters_service_id_key UNIQUE (service_id);


--
-- Name: database_configs_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY database_configs
    ADD CONSTRAINT database_configs_pkey PRIMARY KEY (database_config_id);


--
-- Name: database_names_name_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY database_names
    ADD CONSTRAINT database_names_name_key UNIQUE (name);


--
-- Name: database_names_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY database_names
    ADD CONSTRAINT database_names_pkey PRIMARY KEY (database_name_id);


--
-- Name: database_versions_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY database_versions
    ADD CONSTRAINT database_versions_pkey PRIMARY KEY (id);


--
-- Name: database_versions_version_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY database_versions
    ADD CONSTRAINT database_versions_version_key UNIQUE (version);


--
-- Name: datacenters_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY datacenters
    ADD CONSTRAINT datacenters_pkey PRIMARY KEY (datacenter_id);


--
-- Name: disk_types_disk_type_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY disk_types
    ADD CONSTRAINT disk_types_disk_type_key UNIQUE (disk_type);


--
-- Name: disk_types_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY disk_types
    ADD CONSTRAINT disk_types_pkey PRIMARY KEY (id);


--
-- Name: disks_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY disks
    ADD CONSTRAINT disks_pkey PRIMARY KEY (disk_id);


--
-- Name: distributions_name_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY distributions
    ADD CONSTRAINT distributions_name_key UNIQUE (name);


--
-- Name: distributions_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY distributions
    ADD CONSTRAINT distributions_pkey PRIMARY KEY (id);


--
-- Name: ip_addresses_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY ip_addresses
    ADD CONSTRAINT ip_addresses_pkey PRIMARY KEY (ip_address_id);


--
-- Name: ip_ports_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY ip_ports
    ADD CONSTRAINT ip_ports_pkey PRIMARY KEY (port_id);


--
-- Name: ip_ports_port_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY ip_ports
    ADD CONSTRAINT ip_ports_port_key UNIQUE (port, protocol_id);


--
-- Name: live_xen_maps_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY live_xen_maps
    ADD CONSTRAINT live_xen_maps_pkey PRIMARY KEY (live_xen_map_id);


--
-- Name: local_port_unique; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY services
    ADD CONSTRAINT local_port_unique UNIQUE (local_port, protocol_id, not_unique);


--
-- Name: locations_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (location_id);


--
-- Name: network_acls_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY network_acls
    ADD CONSTRAINT network_acls_pkey PRIMARY KEY (acl_id, network_id);


--
-- Name: network_switch_ports_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY network_switch_ports
    ADD CONSTRAINT network_switch_ports_pkey PRIMARY KEY (id);


--
-- Name: network_switch_ports_switch_id_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY network_switch_ports
    ADD CONSTRAINT network_switch_ports_switch_id_key UNIQUE (switch_id, port);


--
-- Name: network_types_name_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY network_types
    ADD CONSTRAINT network_types_name_key UNIQUE (name);


--
-- Name: network_types_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY network_types
    ADD CONSTRAINT network_types_pkey PRIMARY KEY (network_type_id);


--
-- Name: networks_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY networks
    ADD CONSTRAINT networks_pkey PRIMARY KEY (network_id);


--
-- Name: nics_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY nics
    ADD CONSTRAINT nics_pkey PRIMARY KEY (nic_id);


--
-- Name: node_acls_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY node_acls
    ADD CONSTRAINT node_acls_pkey PRIMARY KEY (acl_id, node_id);


--
-- Name: node_disks_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY node_disks
    ADD CONSTRAINT node_disks_pkey PRIMARY KEY (id);


--
-- Name: node_type_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY node_type
    ADD CONSTRAINT node_type_pkey PRIMARY KEY (node_type_id);


--
-- Name: nodes_hostname_datacenter_id; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY nodes
    ADD CONSTRAINT nodes_hostname_datacenter_id UNIQUE (hostname, datacenter_id);


--
-- Name: nodes_nics_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY node_nics
    ADD CONSTRAINT nodes_nics_pkey PRIMARY KEY (node_id, nic_id);


--
-- Name: nodes_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY nodes
    ADD CONSTRAINT nodes_pkey PRIMARY KEY (node_id);


--
-- Name: os_versions_distribution_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY os_versions
    ADD CONSTRAINT os_versions_distribution_key UNIQUE (distribution, kernel);


--
-- Name: os_versions_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY os_versions
    ADD CONSTRAINT os_versions_pkey PRIMARY KEY (id);


--
-- Name: pdus_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY pdus
    ADD CONSTRAINT pdus_pkey PRIMARY KEY (id);


--
-- Name: policies_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY policies
    ADD CONSTRAINT policies_pkey PRIMARY KEY (policy_id);


--
-- Name: policy_acls_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY policy_acls
    ADD CONSTRAINT policy_acls_pkey PRIMARY KEY (policy_id, acl_id);


--
-- Name: protocols_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY protocols
    ADD CONSTRAINT protocols_pkey PRIMARY KEY (protocol_id);


--
-- Name: protocols_proto_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY protocols
    ADD CONSTRAINT protocols_proto_key UNIQUE (proto);


--
-- Name: puds__pdu_id_outlet_no; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY pdus
    ADD CONSTRAINT puds__pdu_id_outlet_no UNIQUE (pdu_id, outlet_no);


--
-- Name: rampart_service_templates_network_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY rampart_service_templates
    ADD CONSTRAINT rampart_service_templates_network_key UNIQUE (network, port, protocol, direction);


--
-- Name: rampart_service_templates_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY rampart_service_templates
    ADD CONSTRAINT rampart_service_templates_pkey PRIMARY KEY (id);


--
-- Name: rampart_services_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY rampart_services
    ADD CONSTRAINT rampart_services_pkey PRIMARY KEY (id);


--
-- Name: ramparts_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY ramparts
    ADD CONSTRAINT ramparts_pkey PRIMARY KEY (id);


--
-- Name: roles_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (role_id);


--
-- Name: san_nodes_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY san_nodes
    ADD CONSTRAINT san_nodes_pkey PRIMARY KEY (san_id, node_id, ip_address_id);


--
-- Name: sans_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY sans
    ADD CONSTRAINT sans_pkey PRIMARY KEY (san_id);


--
-- Name: serial_baud_rates_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY serial_baud_rates
    ADD CONSTRAINT serial_baud_rates_pkey PRIMARY KEY (speed);


--
-- Name: serial_consoles_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY serial_consoles
    ADD CONSTRAINT serial_consoles_pkey PRIMARY KEY (id);


--
-- Name: service_dependencies_parent_id_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY service_dependencies
    ADD CONSTRAINT service_dependencies_parent_id_key UNIQUE (parent_id, child_id);


--
-- Name: service_dependencies_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY service_dependencies
    ADD CONSTRAINT service_dependencies_pkey PRIMARY KEY (id);


--
-- Name: service_locations_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY service_locations
    ADD CONSTRAINT service_locations_pkey PRIMARY KEY (service_id, datacenter_id);


--
-- Name: service_ports_local_port_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY service_ports
    ADD CONSTRAINT service_ports_local_port_key UNIQUE (local_port, has_proxy);


--
-- Name: service_ports_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY service_ports
    ADD CONSTRAINT service_ports_pkey PRIMARY KEY (service_id, port_id);


--
-- Name: services_ip_port_proto_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY services
    ADD CONSTRAINT services_ip_port_proto_key UNIQUE (ip_address, service_port, protocol_id);


--
-- Name: services_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY services
    ADD CONSTRAINT services_pkey PRIMARY KEY (service_id);


--
-- Name: sessions_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (session_id);


--
-- Name: u_serial_consoles__port_scs_id; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY serial_consoles
    ADD CONSTRAINT u_serial_consoles__port_scs_id UNIQUE (scs_id, port);


--
-- Name: user_roles_user_id_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY user_roles
    ADD CONSTRAINT user_roles_user_id_key UNIQUE (user_id, role_id);


--
-- Name: users_login_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_login_key UNIQUE (login);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: versions_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY versions
    ADD CONSTRAINT versions_pkey PRIMARY KEY (id);


--
-- Name: xen_mappings_guest_id_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY xen_mappings
    ADD CONSTRAINT xen_mappings_guest_id_key UNIQUE (guest_id);


--
-- Name: xen_mappings_host_id_key; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY xen_mappings
    ADD CONSTRAINT xen_mappings_host_id_key UNIQUE (host_id, guest_id);


--
-- Name: xen_mappings_pkey; Type: CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

ALTER TABLE ONLY xen_mappings
    ADD CONSTRAINT xen_mappings_pkey PRIMARY KEY (id);


--
-- Name: acls_port_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX acls_port_id ON acls USING btree (port_id);


--
-- Name: cluster_nodes__cluster_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX cluster_nodes__cluster_id ON cluster_nodes USING btree (cluster_id);


--
-- Name: cluster_nodes__ip_address; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX cluster_nodes__ip_address ON cluster_nodes USING btree (ip_address);


--
-- Name: cluster_nodes__node_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX cluster_nodes__node_id ON cluster_nodes USING btree (node_id);


--
-- Name: cluster_nodes_ip_address_key; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX cluster_nodes_ip_address_key ON cluster_nodes USING btree (cluster_id, ip_address);


--
-- Name: cluster_services__cluster_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX cluster_services__cluster_id ON cluster_services USING btree (cluster_id);


--
-- Name: cluster_services__service_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX cluster_services__service_id ON cluster_services USING btree (service_id);


--
-- Name: index_versions_on_item_type_and_item_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX index_versions_on_item_type_and_item_id ON versions USING btree (item_type, item_id);


--
-- Name: ips_search_address; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX ips_search_address ON ip_addresses USING btree (set_masklen(ip_address, 32));


--
-- Name: live_xen_maps_client_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX live_xen_maps_client_id ON live_xen_maps USING btree (client_id);


--
-- Name: live_xen_maps_host_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX live_xen_maps_host_id ON live_xen_maps USING btree (host_id);


--
-- Name: network_switch_ports_node_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX network_switch_ports_node_id ON network_switch_ports USING btree (node_id);


--
-- Name: network_switch_ports_switch_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX network_switch_ports_switch_id ON network_switch_ports USING btree (switch_id);


--
-- Name: networks_ip_range; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE UNIQUE INDEX networks_ip_range ON networks USING btree (ip_range);


--
-- Name: nics_mac_address_uniq; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE UNIQUE INDEX nics_mac_address_uniq ON nics USING btree (mac_address);


--
-- Name: node_disks__disk_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX node_disks__disk_id ON node_disks USING btree (disk_id);


--
-- Name: node_disks__node_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX node_disks__node_id ON node_disks USING btree (node_id);


--
-- Name: nodes__node_type_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX nodes__node_type_id ON nodes USING btree (node_type_id);


--
-- Name: nodes_active; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX nodes_active ON nodes USING btree (hostname) WHERE (node_type_id <> 3);


--
-- Name: nodes_datacenter_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX nodes_datacenter_id ON nodes USING btree (datacenter_id);


--
-- Name: nodes_mgmt_ip_address_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX nodes_mgmt_ip_address_id ON nodes USING btree (mgmt_ip_address_id);


--
-- Name: pdus_node_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX pdus_node_id ON pdus USING btree (node_id);


--
-- Name: pdus_pdu_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX pdus_pdu_id ON pdus USING btree (pdu_id);


--
-- Name: ramparts_locale_ip_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE UNIQUE INDEX ramparts_locale_ip_id ON ramparts USING btree (locale_ip_address_id);


--
-- Name: ramparts_public_ip_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE UNIQUE INDEX ramparts_public_ip_id ON ramparts USING btree (public_ip_address_id);


--
-- Name: san_nodes_ip_address_id_uniq; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE UNIQUE INDEX san_nodes_ip_address_id_uniq ON san_nodes USING btree (ip_address_id);


--
-- Name: serial_consoles_node_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX serial_consoles_node_id ON serial_consoles USING btree (node_id);


--
-- Name: serial_consoles_scs_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX serial_consoles_scs_id ON serial_consoles USING btree (scs_id);


--
-- Name: sessions_session_id_idx; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX sessions_session_id_idx ON sessions USING btree (session_id);


--
-- Name: sessions_updated_at_idx; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX sessions_updated_at_idx ON sessions USING btree (updated_at);


--
-- Name: versions_created_at; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX versions_created_at ON versions USING btree (created_at);


--
-- Name: versions_created_at2; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX versions_created_at2 ON versions USING btree (((created_at)::date));


--
-- Name: versions_user_id; Type: INDEX; Schema: cnu_net; Owner: cnu_it_config; Tablespace: 
--

CREATE INDEX versions_user_id ON versions USING btree (whodunnit) WHERE ((whodunnit)::text ~ '^[0-9][0-9]*$'::text);


--
-- Name: sessions_insert; Type: TRIGGER; Schema: cnu_net; Owner: cnu_it_config
--

CREATE TRIGGER sessions_insert
    BEFORE INSERT ON sessions
    FOR EACH ROW
    EXECUTE PROCEDURE trigger_created_at();


--
-- Name: sessions_update; Type: TRIGGER; Schema: cnu_net; Owner: cnu_it_config
--

CREATE TRIGGER sessions_update
    BEFORE UPDATE ON sessions
    FOR EACH ROW
    EXECUTE PROCEDURE trigger_updated_at();


--
-- Name: trigger__non_private_network_ip_unique; Type: TRIGGER; Schema: cnu_net; Owner: cnu_it_config
--

CREATE CONSTRAINT TRIGGER trigger__non_private_network_ip_unique
    AFTER INSERT OR UPDATE ON ip_addresses
DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE PROCEDURE check_unique_ip_address();


--
-- Name: users_insert; Type: TRIGGER; Schema: cnu_net; Owner: cnu_it_config
--

CREATE TRIGGER users_insert
    BEFORE INSERT ON users
    FOR EACH ROW
    EXECUTE PROCEDURE trigger_created_at();


--
-- Name: users_update; Type: TRIGGER; Schema: cnu_net; Owner: cnu_it_config
--

CREATE TRIGGER users_update
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE PROCEDURE trigger_updated_at();


--
-- Name: acls_destination_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY acls
    ADD CONSTRAINT acls_destination_fkey FOREIGN KEY (destination) REFERENCES networks(network_id);


--
-- Name: acls_port_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY acls
    ADD CONSTRAINT acls_port_id_fkey FOREIGN KEY (port_id) REFERENCES ip_ports(port_id);


--
-- Name: bootstraps_model_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY bootstraps
    ADD CONSTRAINT bootstraps_model_id_fkey FOREIGN KEY (model_id) REFERENCES cnu_machine_models(model_id);


--
-- Name: bootstraps_node_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY bootstraps
    ADD CONSTRAINT bootstraps_node_id_fkey FOREIGN KEY (node_id) REFERENCES nodes(node_id);


--
-- Name: cluster_nodes_cluster_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY cluster_nodes
    ADD CONSTRAINT cluster_nodes_cluster_id_fkey FOREIGN KEY (cluster_id) REFERENCES clusters(cluster_id);


--
-- Name: cluster_nodes_node_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY cluster_nodes
    ADD CONSTRAINT cluster_nodes_node_id_fkey FOREIGN KEY (node_id) REFERENCES nodes(node_id) ON DELETE CASCADE;


--
-- Name: cluster_services_cluster_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY cluster_services
    ADD CONSTRAINT cluster_services_cluster_id_fkey FOREIGN KEY (cluster_id) REFERENCES clusters(cluster_id);


--
-- Name: cluster_services_service_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY cluster_services
    ADD CONSTRAINT cluster_services_service_id_fkey FOREIGN KEY (service_id) REFERENCES services(service_id);


--
-- Name: database_accesses_auth_method_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY database_accesses
    ADD CONSTRAINT database_accesses_auth_method_fkey FOREIGN KEY (auth_method) REFERENCES database_auth_methods(auth_method);


--
-- Name: database_accesses_node_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY database_accesses
    ADD CONSTRAINT database_accesses_node_id_fkey FOREIGN KEY (node_id) REFERENCES nodes(node_id);


--
-- Name: database_acls_database_access_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY database_acls
    ADD CONSTRAINT database_acls_database_access_id_fkey FOREIGN KEY (database_access_id) REFERENCES database_accesses(database_access_id);


--
-- Name: database_acls_database_cluster_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY database_acls
    ADD CONSTRAINT database_acls_database_cluster_id_fkey FOREIGN KEY (database_cluster_id) REFERENCES database_clusters(database_cluster_id);


--
-- Name: database_acls_database_cluster_id_fkey1; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY database_acls
    ADD CONSTRAINT database_acls_database_cluster_id_fkey1 FOREIGN KEY (database_cluster_id, database_name_id) REFERENCES database_cluster_database_names(database_cluster_id, database_name_id) DEFERRABLE;


--
-- Name: database_acls_database_name_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY database_acls
    ADD CONSTRAINT database_acls_database_name_id_fkey FOREIGN KEY (database_name_id) REFERENCES database_names(database_name_id);


--
-- Name: database_cluster_database_names_database_cluster_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY database_cluster_database_names
    ADD CONSTRAINT database_cluster_database_names_database_cluster_id_fkey FOREIGN KEY (database_cluster_id) REFERENCES database_clusters(database_cluster_id);


--
-- Name: database_cluster_database_names_database_name_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY database_cluster_database_names
    ADD CONSTRAINT database_cluster_database_names_database_name_id_fkey FOREIGN KEY (database_name_id) REFERENCES database_names(database_name_id);


--
-- Name: database_clusters_database_config_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY database_clusters
    ADD CONSTRAINT database_clusters_database_config_id_fkey FOREIGN KEY (database_config_id) REFERENCES database_configs(database_config_id);


--
-- Name: database_clusters_service_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY database_clusters
    ADD CONSTRAINT database_clusters_service_id_fkey FOREIGN KEY (service_id) REFERENCES services(service_id);


--
-- Name: database_clusters_version_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY database_clusters
    ADD CONSTRAINT database_clusters_version_fkey FOREIGN KEY (version) REFERENCES database_versions(version);


--
-- Name: disks_disk_type_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY disks
    ADD CONSTRAINT disks_disk_type_fkey FOREIGN KEY (disk_type) REFERENCES disk_types(disk_type);


--
-- Name: ip_addresses_network_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY ip_addresses
    ADD CONSTRAINT ip_addresses_network_id_fkey FOREIGN KEY (network_id) REFERENCES networks(network_id);


--
-- Name: ip_ports_protocol_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY ip_ports
    ADD CONSTRAINT ip_ports_protocol_id_fkey FOREIGN KEY (protocol_id) REFERENCES protocols(protocol_id);


--
-- Name: live_xen_maps_client_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY live_xen_maps
    ADD CONSTRAINT live_xen_maps_client_id_fkey FOREIGN KEY (client_id) REFERENCES nodes(node_id);


--
-- Name: live_xen_maps_host_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY live_xen_maps
    ADD CONSTRAINT live_xen_maps_host_id_fkey FOREIGN KEY (host_id) REFERENCES nodes(node_id);


--
-- Name: locations_datacenter_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY locations
    ADD CONSTRAINT locations_datacenter_id_fkey FOREIGN KEY (datacenter_id) REFERENCES datacenters(datacenter_id);


--
-- Name: network_acls_acl_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY network_acls
    ADD CONSTRAINT network_acls_acl_id_fkey FOREIGN KEY (acl_id) REFERENCES acls(acl_id);


--
-- Name: network_acls_network_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY network_acls
    ADD CONSTRAINT network_acls_network_id_fkey FOREIGN KEY (network_id) REFERENCES networks(network_id);


--
-- Name: network_switch_ports_node_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY network_switch_ports
    ADD CONSTRAINT network_switch_ports_node_id_fkey FOREIGN KEY (node_id) REFERENCES nodes(node_id);


--
-- Name: network_switch_ports_switch_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY network_switch_ports
    ADD CONSTRAINT network_switch_ports_switch_id_fkey FOREIGN KEY (switch_id) REFERENCES nodes(node_id);


--
-- Name: networks_network_type_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY networks
    ADD CONSTRAINT networks_network_type_id_fkey FOREIGN KEY (network_type_id) REFERENCES network_types(network_type_id);


--
-- Name: node_acls_acl_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY node_acls
    ADD CONSTRAINT node_acls_acl_id_fkey FOREIGN KEY (acl_id) REFERENCES acls(acl_id);


--
-- Name: node_acls_node_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY node_acls
    ADD CONSTRAINT node_acls_node_id_fkey FOREIGN KEY (node_id) REFERENCES nodes(node_id);


--
-- Name: node_disks_disk_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY node_disks
    ADD CONSTRAINT node_disks_disk_id_fkey FOREIGN KEY (disk_id) REFERENCES disks(disk_id);


--
-- Name: node_disks_node_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY node_disks
    ADD CONSTRAINT node_disks_node_id_fkey FOREIGN KEY (node_id) REFERENCES nodes(node_id);


--
-- Name: nodes_datacenters_fk; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY nodes
    ADD CONSTRAINT nodes_datacenters_fk FOREIGN KEY (datacenter_id) REFERENCES datacenters(datacenter_id);


--
-- Name: nodes_location_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY nodes
    ADD CONSTRAINT nodes_location_id_fkey FOREIGN KEY (location_id) REFERENCES locations(location_id);


--
-- Name: nodes_mgmt_ip_address_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY nodes
    ADD CONSTRAINT nodes_mgmt_ip_address_id_fkey FOREIGN KEY (mgmt_ip_address_id) REFERENCES ip_addresses(ip_address_id);


--
-- Name: nodes_model_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY nodes
    ADD CONSTRAINT nodes_model_id_fkey FOREIGN KEY (model_id) REFERENCES cnu_machine_models(model_id);


--
-- Name: nodes_nics_nic_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY node_nics
    ADD CONSTRAINT nodes_nics_nic_id_fkey FOREIGN KEY (nic_id) REFERENCES nics(nic_id);


--
-- Name: nodes_nics_node_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY node_nics
    ADD CONSTRAINT nodes_nics_node_id_fkey FOREIGN KEY (node_id) REFERENCES nodes(node_id);


--
-- Name: nodes_node_type_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY nodes
    ADD CONSTRAINT nodes_node_type_id_fkey FOREIGN KEY (node_type_id) REFERENCES node_type(node_type_id);


--
-- Name: nodes_os_version_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY nodes
    ADD CONSTRAINT nodes_os_version_id_fkey FOREIGN KEY (os_version_id) REFERENCES os_versions(id);


--
-- Name: os_versions_distribution_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY os_versions
    ADD CONSTRAINT os_versions_distribution_fkey FOREIGN KEY (distribution) REFERENCES distributions(name);


--
-- Name: pdus_pdu_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY pdus
    ADD CONSTRAINT pdus_pdu_id_fkey FOREIGN KEY (pdu_id) REFERENCES nodes(node_id);


--
-- Name: pdus_ps_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY pdus
    ADD CONSTRAINT pdus_ps_id_fkey FOREIGN KEY (node_id) REFERENCES nodes(node_id);


--
-- Name: policy_acls_acl_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY policy_acls
    ADD CONSTRAINT policy_acls_acl_id_fkey FOREIGN KEY (acl_id) REFERENCES acls(acl_id);


--
-- Name: policy_acls_policy_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY policy_acls
    ADD CONSTRAINT policy_acls_policy_id_fkey FOREIGN KEY (policy_id) REFERENCES policies(policy_id);


--
-- Name: rampart_services_rampart_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY rampart_services
    ADD CONSTRAINT rampart_services_rampart_id_fkey FOREIGN KEY (rampart_id) REFERENCES ramparts(id);


--
-- Name: ramparts_locale_ip_address_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY ramparts
    ADD CONSTRAINT ramparts_locale_ip_address_id_fkey FOREIGN KEY (locale_ip_address_id) REFERENCES ip_addresses(ip_address_id);


--
-- Name: ramparts_node_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY ramparts
    ADD CONSTRAINT ramparts_node_id_fkey FOREIGN KEY (node_id) REFERENCES nodes(node_id);


--
-- Name: ramparts_public_ip_address_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY ramparts
    ADD CONSTRAINT ramparts_public_ip_address_id_fkey FOREIGN KEY (public_ip_address_id) REFERENCES ip_addresses(ip_address_id);


--
-- Name: san_nodes_ip_address_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY san_nodes
    ADD CONSTRAINT san_nodes_ip_address_id_fkey FOREIGN KEY (ip_address_id) REFERENCES ip_addresses(ip_address_id);


--
-- Name: san_nodes_node_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY san_nodes
    ADD CONSTRAINT san_nodes_node_id_fkey FOREIGN KEY (node_id) REFERENCES nodes(node_id);


--
-- Name: san_nodes_san_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY san_nodes
    ADD CONSTRAINT san_nodes_san_id_fkey FOREIGN KEY (san_id) REFERENCES sans(san_id);


--
-- Name: sans_network_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY sans
    ADD CONSTRAINT sans_network_id_fkey FOREIGN KEY (network_id) REFERENCES networks(network_id);


--
-- Name: serial_baud_rate_fk; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY cnu_machine_models
    ADD CONSTRAINT serial_baud_rate_fk FOREIGN KEY (serial_baud_rate) REFERENCES serial_baud_rates(speed);


--
-- Name: serial_consoles_node_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY serial_consoles
    ADD CONSTRAINT serial_consoles_node_id_fkey FOREIGN KEY (node_id) REFERENCES nodes(node_id);


--
-- Name: serial_consoles_scs_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY serial_consoles
    ADD CONSTRAINT serial_consoles_scs_id_fkey FOREIGN KEY (scs_id) REFERENCES nodes(node_id);


--
-- Name: service_dependencies_child_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY service_dependencies
    ADD CONSTRAINT service_dependencies_child_id_fkey FOREIGN KEY (child_id) REFERENCES services(service_id);


--
-- Name: service_dependencies_parent_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY service_dependencies
    ADD CONSTRAINT service_dependencies_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES services(service_id);


--
-- Name: service_locations_datacenter_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY service_locations
    ADD CONSTRAINT service_locations_datacenter_id_fkey FOREIGN KEY (datacenter_id) REFERENCES datacenters(datacenter_id);


--
-- Name: service_locations_service_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY service_locations
    ADD CONSTRAINT service_locations_service_id_fkey FOREIGN KEY (service_id) REFERENCES services(service_id);


--
-- Name: service_ports_port_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY service_ports
    ADD CONSTRAINT service_ports_port_id_fkey FOREIGN KEY (port_id) REFERENCES ip_ports(port_id);


--
-- Name: service_ports_service_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY service_ports
    ADD CONSTRAINT service_ports_service_id_fkey FOREIGN KEY (service_id) REFERENCES services(service_id);


--
-- Name: services_protocol_id_fk; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY services
    ADD CONSTRAINT services_protocol_id_fk FOREIGN KEY (protocol_id) REFERENCES protocols(protocol_id);


--
-- Name: user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE CASCADE;


--
-- Name: user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE;


--
-- Name: xen_mappings_guest_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY xen_mappings
    ADD CONSTRAINT xen_mappings_guest_id_fkey FOREIGN KEY (guest_id) REFERENCES nodes(node_id);


--
-- Name: xen_mappings_host_id_fkey; Type: FK CONSTRAINT; Schema: cnu_net; Owner: cnu_it_config
--

ALTER TABLE ONLY xen_mappings
    ADD CONSTRAINT xen_mappings_host_id_fkey FOREIGN KEY (host_id) REFERENCES nodes(node_id);


--
-- Name: cnu_net; Type: ACL; Schema: -; Owner: cnu_it_config
--

REVOKE ALL ON SCHEMA cnu_net FROM PUBLIC;
REVOKE ALL ON SCHEMA cnu_net FROM cnu_it_config;
GRANT ALL ON SCHEMA cnu_net TO cnu_it_config;
GRANT USAGE ON SCHEMA cnu_net TO PUBLIC;
GRANT ALL ON SCHEMA cnu_net TO cnu_it_config;
GRANT USAGE ON SCHEMA cnu_net TO cnu_it_deploy;


--
-- Name: add_guest(integer, integer); Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON FUNCTION add_guest(p_host integer, p_guest integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION add_guest(p_host integer, p_guest integer) FROM cnu_it_config;
GRANT ALL ON FUNCTION add_guest(p_host integer, p_guest integer) TO cnu_it_config;
GRANT ALL ON FUNCTION add_guest(p_host integer, p_guest integer) TO PUBLIC;
GRANT ALL ON FUNCTION add_guest(p_host integer, p_guest integer) TO cnu_it_config;


--
-- Name: add_guest(text, text); Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON FUNCTION add_guest(i_host text, i_guest text) FROM PUBLIC;
REVOKE ALL ON FUNCTION add_guest(i_host text, i_guest text) FROM cnu_it_config;
GRANT ALL ON FUNCTION add_guest(i_host text, i_guest text) TO cnu_it_config;
GRANT ALL ON FUNCTION add_guest(i_host text, i_guest text) TO PUBLIC;
GRANT ALL ON FUNCTION add_guest(i_host text, i_guest text) TO cnu_it_config;


--
-- Name: all_ip_addresses(cidr, numeric); Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON FUNCTION all_ip_addresses(p_network_range cidr, p_skip numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION all_ip_addresses(p_network_range cidr, p_skip numeric) FROM cnu_it_config;
GRANT ALL ON FUNCTION all_ip_addresses(p_network_range cidr, p_skip numeric) TO cnu_it_config;
GRANT ALL ON FUNCTION all_ip_addresses(p_network_range cidr, p_skip numeric) TO PUBLIC;
GRANT ALL ON FUNCTION all_ip_addresses(p_network_range cidr, p_skip numeric) TO cnu_it_deploy;


--
-- Name: all_ip_addresses(cidr); Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON FUNCTION all_ip_addresses(cidr) FROM PUBLIC;
REVOKE ALL ON FUNCTION all_ip_addresses(cidr) FROM cnu_it_config;
GRANT ALL ON FUNCTION all_ip_addresses(cidr) TO cnu_it_config;
GRANT ALL ON FUNCTION all_ip_addresses(cidr) TO PUBLIC;
GRANT ALL ON FUNCTION all_ip_addresses(cidr) TO cnu_it_deploy;


--
-- Name: all_ip_addresses(text); Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON FUNCTION all_ip_addresses(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION all_ip_addresses(text) FROM cnu_it_config;
GRANT ALL ON FUNCTION all_ip_addresses(text) TO cnu_it_config;
GRANT ALL ON FUNCTION all_ip_addresses(text) TO PUBLIC;
GRANT ALL ON FUNCTION all_ip_addresses(text) TO cnu_it_deploy;


--
-- Name: assigned_network_ip_addresses(integer); Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON FUNCTION assigned_network_ip_addresses(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION assigned_network_ip_addresses(integer) FROM cnu_it_config;
GRANT ALL ON FUNCTION assigned_network_ip_addresses(integer) TO cnu_it_config;
GRANT ALL ON FUNCTION assigned_network_ip_addresses(integer) TO PUBLIC;
GRANT ALL ON FUNCTION assigned_network_ip_addresses(integer) TO cnu_it_deploy;


--
-- Name: datacenter_mgmt_network_id(integer); Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON FUNCTION datacenter_mgmt_network_id(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION datacenter_mgmt_network_id(integer) FROM cnu_it_config;
GRANT ALL ON FUNCTION datacenter_mgmt_network_id(integer) TO cnu_it_config;
GRANT ALL ON FUNCTION datacenter_mgmt_network_id(integer) TO PUBLIC;
GRANT ALL ON FUNCTION datacenter_mgmt_network_id(integer) TO cnu_it_deploy;


--
-- Name: get_protocol(text); Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON FUNCTION get_protocol(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_protocol(text) FROM cnu_it_config;
GRANT ALL ON FUNCTION get_protocol(text) TO cnu_it_config;
GRANT ALL ON FUNCTION get_protocol(text) TO PUBLIC;
GRANT ALL ON FUNCTION get_protocol(text) TO cnu_it_deploy;


--
-- Name: is_pdu(integer); Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON FUNCTION is_pdu(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION is_pdu(integer) FROM cnu_it_config;
GRANT ALL ON FUNCTION is_pdu(integer) TO cnu_it_config;
GRANT ALL ON FUNCTION is_pdu(integer) TO PUBLIC;
GRANT ALL ON FUNCTION is_pdu(integer) TO cnu_it_config;


--
-- Name: move_guest(text, text); Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON FUNCTION move_guest(i_guest text, i_host text) FROM PUBLIC;
REVOKE ALL ON FUNCTION move_guest(i_guest text, i_host text) FROM cnu_it_config;
GRANT ALL ON FUNCTION move_guest(i_guest text, i_host text) TO cnu_it_config;
GRANT ALL ON FUNCTION move_guest(i_guest text, i_host text) TO PUBLIC;
GRANT ALL ON FUNCTION move_guest(i_guest text, i_host text) TO cnu_it_config;


--
-- Name: next_cluster_ip_address(integer); Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON FUNCTION next_cluster_ip_address(p_cluster_id integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION next_cluster_ip_address(p_cluster_id integer) FROM cnu_it_config;
GRANT ALL ON FUNCTION next_cluster_ip_address(p_cluster_id integer) TO cnu_it_config;
GRANT ALL ON FUNCTION next_cluster_ip_address(p_cluster_id integer) TO PUBLIC;
GRANT ALL ON FUNCTION next_cluster_ip_address(p_cluster_id integer) TO cnu_it_config;


--
-- Name: next_network_ip_address(integer); Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON FUNCTION next_network_ip_address(p_network_id integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION next_network_ip_address(p_network_id integer) FROM cnu_it_config;
GRANT ALL ON FUNCTION next_network_ip_address(p_network_id integer) TO cnu_it_config;
GRANT ALL ON FUNCTION next_network_ip_address(p_network_id integer) TO PUBLIC;
GRANT ALL ON FUNCTION next_network_ip_address(p_network_id integer) TO cnu_it_deploy;


--
-- Name: remove_guest(integer); Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON FUNCTION remove_guest(p_guest integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION remove_guest(p_guest integer) FROM cnu_it_config;
GRANT ALL ON FUNCTION remove_guest(p_guest integer) TO cnu_it_config;
GRANT ALL ON FUNCTION remove_guest(p_guest integer) TO PUBLIC;
GRANT ALL ON FUNCTION remove_guest(p_guest integer) TO cnu_it_config;


--
-- Name: san_next_ip_address(integer); Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON FUNCTION san_next_ip_address(san integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION san_next_ip_address(san integer) FROM cnu_it_config;
GRANT ALL ON FUNCTION san_next_ip_address(san integer) TO cnu_it_config;
GRANT ALL ON FUNCTION san_next_ip_address(san integer) TO PUBLIC;
GRANT ALL ON FUNCTION san_next_ip_address(san integer) TO cnu_it_config;


--
-- Name: acls; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE acls FROM PUBLIC;
REVOKE ALL ON TABLE acls FROM cnu_it_config;
GRANT ALL ON TABLE acls TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE acls TO cnu_it_deploy;
GRANT SELECT ON TABLE acls TO PUBLIC;


--
-- Name: cluster_nodes; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE cluster_nodes FROM PUBLIC;
REVOKE ALL ON TABLE cluster_nodes FROM cnu_it_config;
GRANT ALL ON TABLE cluster_nodes TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE cluster_nodes TO cnu_it_deploy;
GRANT SELECT ON TABLE cluster_nodes TO PUBLIC;


--
-- Name: nics; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE nics FROM PUBLIC;
REVOKE ALL ON TABLE nics FROM cnu_it_config;
GRANT ALL ON TABLE nics TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE nics TO cnu_it_deploy;
GRANT SELECT ON TABLE nics TO PUBLIC;


--
-- Name: node_nics; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE node_nics FROM PUBLIC;
REVOKE ALL ON TABLE node_nics FROM cnu_it_config;
GRANT ALL ON TABLE node_nics TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE node_nics TO cnu_it_deploy;
GRANT SELECT ON TABLE node_nics TO PUBLIC;


--
-- Name: node_type; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE node_type FROM PUBLIC;
REVOKE ALL ON TABLE node_type FROM cnu_it_config;
GRANT ALL ON TABLE node_type TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE node_type TO cnu_it_deploy;
GRANT SELECT ON TABLE node_type TO PUBLIC;


--
-- Name: nodes; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE nodes FROM PUBLIC;
REVOKE ALL ON TABLE nodes FROM cnu_it_config;
GRANT ALL ON TABLE nodes TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE nodes TO cnu_it_deploy;
GRANT SELECT ON TABLE nodes TO PUBLIC;


--
-- Name: available_nodes; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE available_nodes FROM PUBLIC;
REVOKE ALL ON TABLE available_nodes FROM cnu_it_config;
GRANT ALL ON TABLE available_nodes TO cnu_it_config;
GRANT ALL ON TABLE available_nodes TO cnu_it_config;
GRANT SELECT ON TABLE available_nodes TO cnu_it_deploy;


--
-- Name: bootstraps; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE bootstraps FROM PUBLIC;
REVOKE ALL ON TABLE bootstraps FROM cnu_it_config;
GRANT ALL ON TABLE bootstraps TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE bootstraps TO cnu_it_deploy;


--
-- Name: bootstraps_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE bootstraps_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE bootstraps_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE bootstraps_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE bootstraps_id_seq TO cnu_it_deploy;


--
-- Name: cluster_services; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE cluster_services FROM PUBLIC;
REVOKE ALL ON TABLE cluster_services FROM cnu_it_config;
GRANT ALL ON TABLE cluster_services TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE cluster_services TO cnu_it_deploy;
GRANT SELECT ON TABLE cluster_services TO PUBLIC;


--
-- Name: clusters; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE clusters FROM PUBLIC;
REVOKE ALL ON TABLE clusters FROM cnu_it_config;
GRANT ALL ON TABLE clusters TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE clusters TO cnu_it_deploy;
GRANT SELECT ON TABLE clusters TO PUBLIC;


--
-- Name: protocols; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE protocols FROM PUBLIC;
REVOKE ALL ON TABLE protocols FROM cnu_it_config;
GRANT ALL ON TABLE protocols TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE protocols TO cnu_it_deploy;
GRANT SELECT ON TABLE protocols TO PUBLIC;


--
-- Name: services; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE services FROM PUBLIC;
REVOKE ALL ON TABLE services FROM cnu_it_config;
GRANT ALL ON TABLE services TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE services TO cnu_it_deploy;
GRANT SELECT ON TABLE services TO PUBLIC;


--
-- Name: cluster_configurations; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE cluster_configurations FROM PUBLIC;
REVOKE ALL ON TABLE cluster_configurations FROM cnu_it_config;
GRANT ALL ON TABLE cluster_configurations TO cnu_it_config;
GRANT ALL ON TABLE cluster_configurations TO cnu_it_config;
GRANT SELECT ON TABLE cluster_configurations TO cnu_it_deploy;


--
-- Name: cluster_configurations2; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE cluster_configurations2 FROM PUBLIC;
REVOKE ALL ON TABLE cluster_configurations2 FROM cnu_it_config;
GRANT ALL ON TABLE cluster_configurations2 TO cnu_it_config;
GRANT ALL ON TABLE cluster_configurations2 TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE cluster_configurations2 TO cnu_it_deploy;


--
-- Name: clusters_cluster_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE clusters_cluster_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE clusters_cluster_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE clusters_cluster_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE clusters_cluster_id_seq TO cnu_it_deploy;


--
-- Name: cnu_machine_models; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE cnu_machine_models FROM PUBLIC;
REVOKE ALL ON TABLE cnu_machine_models FROM cnu_it_config;
GRANT ALL ON TABLE cnu_machine_models TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE cnu_machine_models TO cnu_it_deploy;
GRANT SELECT ON TABLE cnu_machine_models TO PUBLIC;


--
-- Name: cnu_machine_models_model_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE cnu_machine_models_model_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE cnu_machine_models_model_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE cnu_machine_models_model_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE cnu_machine_models_model_id_seq TO cnu_it_deploy;


--
-- Name: database_accesses; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE database_accesses FROM PUBLIC;
REVOKE ALL ON TABLE database_accesses FROM cnu_it_config;
GRANT ALL ON TABLE database_accesses TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE database_accesses TO cnu_it_deploy;
GRANT SELECT ON TABLE database_accesses TO PUBLIC;


--
-- Name: database_accesses_database_access_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE database_accesses_database_access_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE database_accesses_database_access_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE database_accesses_database_access_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE database_accesses_database_access_id_seq TO cnu_it_deploy;


--
-- Name: database_acls; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE database_acls FROM PUBLIC;
REVOKE ALL ON TABLE database_acls FROM cnu_it_config;
GRANT ALL ON TABLE database_acls TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE database_acls TO cnu_it_deploy;
GRANT SELECT ON TABLE database_acls TO PUBLIC;


--
-- Name: database_acls_database_acl_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE database_acls_database_acl_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE database_acls_database_acl_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE database_acls_database_acl_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE database_acls_database_acl_id_seq TO cnu_it_deploy;


--
-- Name: database_cluster_database_names; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE database_cluster_database_names FROM PUBLIC;
REVOKE ALL ON TABLE database_cluster_database_names FROM cnu_it_config;
GRANT ALL ON TABLE database_cluster_database_names TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE database_cluster_database_names TO cnu_it_deploy;
GRANT SELECT ON TABLE database_cluster_database_names TO PUBLIC;


--
-- Name: database_clusters; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE database_clusters FROM PUBLIC;
REVOKE ALL ON TABLE database_clusters FROM cnu_it_config;
GRANT ALL ON TABLE database_clusters TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE database_clusters TO cnu_it_deploy;
GRANT SELECT ON TABLE database_clusters TO PUBLIC;


--
-- Name: database_clusters_database_cluster_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE database_clusters_database_cluster_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE database_clusters_database_cluster_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE database_clusters_database_cluster_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE database_clusters_database_cluster_id_seq TO cnu_it_deploy;


--
-- Name: database_configs; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE database_configs FROM PUBLIC;
REVOKE ALL ON TABLE database_configs FROM cnu_it_config;
GRANT ALL ON TABLE database_configs TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE database_configs TO cnu_it_deploy;
GRANT SELECT ON TABLE database_configs TO PUBLIC;


--
-- Name: database_configs_database_config_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE database_configs_database_config_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE database_configs_database_config_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE database_configs_database_config_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE database_configs_database_config_id_seq TO cnu_it_deploy;


--
-- Name: database_names; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE database_names FROM PUBLIC;
REVOKE ALL ON TABLE database_names FROM cnu_it_config;
GRANT ALL ON TABLE database_names TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE database_names TO cnu_it_deploy;
GRANT SELECT ON TABLE database_names TO PUBLIC;


--
-- Name: database_names_database_name_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE database_names_database_name_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE database_names_database_name_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE database_names_database_name_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE database_names_database_name_id_seq TO cnu_it_deploy;


--
-- Name: database_versions; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE database_versions FROM PUBLIC;
REVOKE ALL ON TABLE database_versions FROM cnu_it_config;
GRANT ALL ON TABLE database_versions TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE database_versions TO cnu_it_deploy;
GRANT SELECT ON TABLE database_versions TO PUBLIC;


--
-- Name: database_versions_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE database_versions_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE database_versions_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE database_versions_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE database_versions_id_seq TO cnu_it_deploy;


--
-- Name: datacenters; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE datacenters FROM PUBLIC;
REVOKE ALL ON TABLE datacenters FROM cnu_it_config;
GRANT ALL ON TABLE datacenters TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE datacenters TO cnu_it_deploy;
GRANT SELECT ON TABLE datacenters TO PUBLIC;


--
-- Name: datacenters_datacenter_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE datacenters_datacenter_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE datacenters_datacenter_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE datacenters_datacenter_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE datacenters_datacenter_id_seq TO cnu_it_deploy;


--
-- Name: disk_types; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE disk_types FROM PUBLIC;
REVOKE ALL ON TABLE disk_types FROM cnu_it_config;
GRANT ALL ON TABLE disk_types TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE disk_types TO cnu_it_deploy;
GRANT SELECT ON TABLE disk_types TO PUBLIC;


--
-- Name: disk_types_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE disk_types_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE disk_types_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE disk_types_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE disk_types_id_seq TO cnu_it_deploy;


--
-- Name: disks; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE disks FROM PUBLIC;
REVOKE ALL ON TABLE disks FROM cnu_it_config;
GRANT ALL ON TABLE disks TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE disks TO cnu_it_deploy;
GRANT SELECT ON TABLE disks TO PUBLIC;


--
-- Name: disks_disk_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE disks_disk_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE disks_disk_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE disks_disk_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE disks_disk_id_seq TO cnu_it_deploy;


--
-- Name: distributions; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE distributions FROM PUBLIC;
REVOKE ALL ON TABLE distributions FROM cnu_it_config;
GRANT ALL ON TABLE distributions TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE distributions TO cnu_it_deploy;
GRANT SELECT ON TABLE distributions TO PUBLIC;


--
-- Name: distributions_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE distributions_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE distributions_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE distributions_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE distributions_id_seq TO cnu_it_deploy;


--
-- Name: host_macs; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE host_macs FROM PUBLIC;
REVOKE ALL ON TABLE host_macs FROM cnu_it_config;
GRANT ALL ON TABLE host_macs TO cnu_it_config;
GRANT ALL ON TABLE host_macs TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE host_macs TO cnu_it_deploy;


--
-- Name: ip_ports; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE ip_ports FROM PUBLIC;
REVOKE ALL ON TABLE ip_ports FROM cnu_it_config;
GRANT ALL ON TABLE ip_ports TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE ip_ports TO cnu_it_deploy;
GRANT SELECT ON TABLE ip_ports TO PUBLIC;


--
-- Name: live_xen_maps; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE live_xen_maps FROM PUBLIC;
REVOKE ALL ON TABLE live_xen_maps FROM cnu_it_config;
GRANT ALL ON TABLE live_xen_maps TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE live_xen_maps TO cnu_it_deploy;
GRANT SELECT ON TABLE live_xen_maps TO PUBLIC;


--
-- Name: live_xen_maps_live_xen_map_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE live_xen_maps_live_xen_map_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE live_xen_maps_live_xen_map_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE live_xen_maps_live_xen_map_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE live_xen_maps_live_xen_map_id_seq TO cnu_it_deploy;


--
-- Name: locations; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE locations FROM PUBLIC;
REVOKE ALL ON TABLE locations FROM cnu_it_config;
GRANT ALL ON TABLE locations TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE locations TO cnu_it_deploy;
GRANT SELECT ON TABLE locations TO PUBLIC;


--
-- Name: location_nodes; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE location_nodes FROM PUBLIC;
REVOKE ALL ON TABLE location_nodes FROM cnu_it_config;
GRANT ALL ON TABLE location_nodes TO cnu_it_config;
GRANT ALL ON TABLE location_nodes TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE location_nodes TO cnu_it_deploy;


--
-- Name: locations_location_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE locations_location_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE locations_location_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE locations_location_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE locations_location_id_seq TO cnu_it_deploy;


--
-- Name: network_acls; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE network_acls FROM PUBLIC;
REVOKE ALL ON TABLE network_acls FROM cnu_it_config;
GRANT ALL ON TABLE network_acls TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE network_acls TO cnu_it_deploy;
GRANT SELECT ON TABLE network_acls TO PUBLIC;


--
-- Name: network_switch_ports; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE network_switch_ports FROM PUBLIC;
REVOKE ALL ON TABLE network_switch_ports FROM cnu_it_config;
GRANT ALL ON TABLE network_switch_ports TO cnu_it_config;
GRANT SELECT ON TABLE network_switch_ports TO PUBLIC;
GRANT SELECT,REFERENCES ON TABLE network_switch_ports TO cnu_it_deploy;


--
-- Name: network_switch_ports_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE network_switch_ports_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE network_switch_ports_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE network_switch_ports_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE network_switch_ports_id_seq TO cnu_it_deploy;


--
-- Name: nics_nic_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE nics_nic_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE nics_nic_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE nics_nic_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE nics_nic_id_seq TO cnu_it_deploy;


--
-- Name: node_acls; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE node_acls FROM PUBLIC;
REVOKE ALL ON TABLE node_acls FROM cnu_it_config;
GRANT ALL ON TABLE node_acls TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE node_acls TO cnu_it_deploy;
GRANT SELECT ON TABLE node_acls TO PUBLIC;


--
-- Name: node_disks; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE node_disks FROM PUBLIC;
REVOKE ALL ON TABLE node_disks FROM cnu_it_config;
GRANT ALL ON TABLE node_disks TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE node_disks TO cnu_it_deploy;
GRANT SELECT ON TABLE node_disks TO PUBLIC;


--
-- Name: node_disks_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE node_disks_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE node_disks_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE node_disks_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE node_disks_id_seq TO cnu_it_deploy;


--
-- Name: node_type_node_type_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE node_type_node_type_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE node_type_node_type_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE node_type_node_type_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE node_type_node_type_id_seq TO cnu_it_deploy;


--
-- Name: nodes_node_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE nodes_node_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE nodes_node_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE nodes_node_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE nodes_node_id_seq TO cnu_it_deploy;


--
-- Name: os_versions; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE os_versions FROM PUBLIC;
REVOKE ALL ON TABLE os_versions FROM cnu_it_config;
GRANT ALL ON TABLE os_versions TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE os_versions TO cnu_it_deploy;
GRANT SELECT ON TABLE os_versions TO PUBLIC;


--
-- Name: os_versions_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE os_versions_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE os_versions_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE os_versions_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE os_versions_id_seq TO cnu_it_deploy;


--
-- Name: pdus; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE pdus FROM PUBLIC;
REVOKE ALL ON TABLE pdus FROM cnu_it_config;
GRANT ALL ON TABLE pdus TO cnu_it_config;
GRANT SELECT ON TABLE pdus TO PUBLIC;
GRANT SELECT,REFERENCES ON TABLE pdus TO cnu_it_deploy;


--
-- Name: pdus_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE pdus_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE pdus_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE pdus_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE pdus_id_seq TO cnu_it_deploy;


--
-- Name: policies; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE policies FROM PUBLIC;
REVOKE ALL ON TABLE policies FROM cnu_it_config;
GRANT ALL ON TABLE policies TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE policies TO cnu_it_deploy;
GRANT SELECT ON TABLE policies TO PUBLIC;


--
-- Name: policy_acls; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE policy_acls FROM PUBLIC;
REVOKE ALL ON TABLE policy_acls FROM cnu_it_config;
GRANT ALL ON TABLE policy_acls TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE policy_acls TO cnu_it_deploy;
GRANT SELECT ON TABLE policy_acls TO PUBLIC;


--
-- Name: protocols_protocol_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE protocols_protocol_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE protocols_protocol_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE protocols_protocol_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE protocols_protocol_id_seq TO cnu_it_deploy;


--
-- Name: rampart_service_templates; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE rampart_service_templates FROM PUBLIC;
REVOKE ALL ON TABLE rampart_service_templates FROM cnu_it_config;
GRANT ALL ON TABLE rampart_service_templates TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE rampart_service_templates TO cnu_it_deploy;
GRANT SELECT ON TABLE rampart_service_templates TO PUBLIC;


--
-- Name: rampart_service_templates_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE rampart_service_templates_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE rampart_service_templates_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE rampart_service_templates_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE rampart_service_templates_id_seq TO cnu_it_deploy;


--
-- Name: rampart_services; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE rampart_services FROM PUBLIC;
REVOKE ALL ON TABLE rampart_services FROM cnu_it_config;
GRANT ALL ON TABLE rampart_services TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE rampart_services TO cnu_it_deploy;


--
-- Name: rampart_services_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE rampart_services_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE rampart_services_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE rampart_services_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE rampart_services_id_seq TO cnu_it_deploy;


--
-- Name: ramparts; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE ramparts FROM PUBLIC;
REVOKE ALL ON TABLE ramparts FROM cnu_it_config;
GRANT ALL ON TABLE ramparts TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE ramparts TO cnu_it_deploy;


--
-- Name: ramparts_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE ramparts_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE ramparts_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE ramparts_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE ramparts_id_seq TO cnu_it_deploy;


--
-- Name: roles; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE roles FROM PUBLIC;
REVOKE ALL ON TABLE roles FROM cnu_it_config;
GRANT ALL ON TABLE roles TO cnu_it_config;
GRANT SELECT ON TABLE roles TO PUBLIC;
GRANT SELECT,REFERENCES ON TABLE roles TO cnu_it_deploy;


--
-- Name: roles_role_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE roles_role_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE roles_role_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE roles_role_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE roles_role_id_seq TO cnu_it_deploy;


--
-- Name: san_nodes; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE san_nodes FROM PUBLIC;
REVOKE ALL ON TABLE san_nodes FROM cnu_it_config;
GRANT ALL ON TABLE san_nodes TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE san_nodes TO cnu_it_deploy;
GRANT SELECT ON TABLE san_nodes TO PUBLIC;


--
-- Name: sans; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE sans FROM PUBLIC;
REVOKE ALL ON TABLE sans FROM cnu_it_config;
GRANT ALL ON TABLE sans TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE sans TO cnu_it_deploy;
GRANT SELECT ON TABLE sans TO PUBLIC;


--
-- Name: sans_san_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE sans_san_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE sans_san_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE sans_san_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE sans_san_id_seq TO cnu_it_deploy;


--
-- Name: serial_baud_rates; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE serial_baud_rates FROM PUBLIC;
REVOKE ALL ON TABLE serial_baud_rates FROM cnu_it_config;
GRANT ALL ON TABLE serial_baud_rates TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE serial_baud_rates TO cnu_it_deploy;


--
-- Name: serial_consoles; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE serial_consoles FROM PUBLIC;
REVOKE ALL ON TABLE serial_consoles FROM cnu_it_config;
GRANT ALL ON TABLE serial_consoles TO cnu_it_config;
GRANT SELECT ON TABLE serial_consoles TO PUBLIC;
GRANT SELECT ON TABLE serial_consoles TO cnu_it_deploy;


--
-- Name: serial_consoles_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE serial_consoles_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE serial_consoles_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE serial_consoles_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE serial_consoles_id_seq TO cnu_it_deploy;


--
-- Name: service_dependencies; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE service_dependencies FROM PUBLIC;
REVOKE ALL ON TABLE service_dependencies FROM cnu_it_config;
GRANT ALL ON TABLE service_dependencies TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE service_dependencies TO cnu_it_deploy;
GRANT SELECT ON TABLE service_dependencies TO PUBLIC;


--
-- Name: service_dependencies_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE service_dependencies_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE service_dependencies_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE service_dependencies_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE service_dependencies_id_seq TO cnu_it_deploy;


--
-- Name: service_locations; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE service_locations FROM PUBLIC;
REVOKE ALL ON TABLE service_locations FROM cnu_it_config;
GRANT ALL ON TABLE service_locations TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE service_locations TO cnu_it_deploy;
GRANT SELECT ON TABLE service_locations TO PUBLIC;


--
-- Name: service_ports; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE service_ports FROM PUBLIC;
REVOKE ALL ON TABLE service_ports FROM cnu_it_config;
GRANT ALL ON TABLE service_ports TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE service_ports TO cnu_it_deploy;
GRANT SELECT ON TABLE service_ports TO PUBLIC;


--
-- Name: services_service_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE services_service_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE services_service_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE services_service_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE services_service_id_seq TO cnu_it_deploy;


--
-- Name: sessions; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE sessions FROM PUBLIC;
REVOKE ALL ON TABLE sessions FROM cnu_it_config;
GRANT ALL ON TABLE sessions TO cnu_it_config;
GRANT SELECT ON TABLE sessions TO PUBLIC;
GRANT SELECT,REFERENCES ON TABLE sessions TO cnu_it_deploy;


--
-- Name: sessions_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE sessions_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE sessions_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE sessions_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE sessions_id_seq TO cnu_it_deploy;


--
-- Name: xen_mappings; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE xen_mappings FROM PUBLIC;
REVOKE ALL ON TABLE xen_mappings FROM cnu_it_config;
GRANT ALL ON TABLE xen_mappings TO cnu_it_config;
GRANT SELECT ON TABLE xen_mappings TO PUBLIC;
GRANT SELECT ON TABLE xen_mappings TO cnu_it_deploy;


--
-- Name: unassigned_guest_nodes; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE unassigned_guest_nodes FROM PUBLIC;
REVOKE ALL ON TABLE unassigned_guest_nodes FROM cnu_it_config;
GRANT ALL ON TABLE unassigned_guest_nodes TO cnu_it_config;
GRANT ALL ON TABLE unassigned_guest_nodes TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE unassigned_guest_nodes TO cnu_it_deploy;


--
-- Name: user_roles; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE user_roles FROM PUBLIC;
REVOKE ALL ON TABLE user_roles FROM cnu_it_config;
GRANT ALL ON TABLE user_roles TO cnu_it_config;
GRANT SELECT ON TABLE user_roles TO PUBLIC;
GRANT SELECT,REFERENCES ON TABLE user_roles TO cnu_it_deploy;


--
-- Name: user_roles_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE user_roles_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE user_roles_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE user_roles_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE user_roles_id_seq TO cnu_it_deploy;


--
-- Name: users; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE users FROM PUBLIC;
REVOKE ALL ON TABLE users FROM cnu_it_config;
GRANT ALL ON TABLE users TO cnu_it_config;
GRANT SELECT ON TABLE users TO PUBLIC;
GRANT SELECT,REFERENCES ON TABLE users TO cnu_it_deploy;


--
-- Name: users_user_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE users_user_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE users_user_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE users_user_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE users_user_id_seq TO cnu_it_deploy;


--
-- Name: versions; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON TABLE versions FROM PUBLIC;
REVOKE ALL ON TABLE versions FROM cnu_it_config;
GRANT ALL ON TABLE versions TO cnu_it_config;
GRANT SELECT,REFERENCES ON TABLE versions TO cnu_it_deploy;


--
-- Name: versions_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE versions_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE versions_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE versions_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE versions_id_seq TO cnu_it_deploy;


--
-- Name: xen_mappings_id_seq; Type: ACL; Schema: cnu_net; Owner: cnu_it_config
--

REVOKE ALL ON SEQUENCE xen_mappings_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE xen_mappings_id_seq FROM cnu_it_config;
GRANT ALL ON SEQUENCE xen_mappings_id_seq TO cnu_it_config;
GRANT USAGE ON SEQUENCE xen_mappings_id_seq TO cnu_it_deploy;


--
-- PostgreSQL database dump complete
--

