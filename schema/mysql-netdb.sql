SET storage_engine=MYISAM;

-- Schema definition for TABLE ACCESS_DATA
drop table if exists access_data;
create table access_data 
(
 dataid integer not null auto_increment primary key,
 id integer not null,
 updateflag integer, 
 userid varchar(30) not null, 
 type varchar(30), 
 domain varchar(30), 
 subnet varchar(30), 
 flag varchar(30), 
 action varchar(30)
);

create index access_data_id ON access_data (id);
create index access_data_uf ON access_data (updateflag);
create index access_data_userid ON access_data (userid);

-- Schema definition for TABLE ACCESS_RULES
create table access_rules 
(
 id integer not null auto_increment primary key, 
 who varchar(2000) not null, 
 types varchar(2000), 
 domains varchar(2000), 
 subnets varchar(2000), 
 flags varchar(500), 
 actions varchar(30)
);

-- Schema definition for TABLE ADMIN_HOST_OPTIONS
create table admin_host_options 
(
 host varchar(120) not null, 
 config varchar(250) not null, 
 tstamp datetime not null
);

create index admin_host_options_h ON admin_host_options (host);
create unique index admin_host_options_hc ON admin_host_options (host, config);

-- Schema definition for TABLE DHCP_ACKLOG
create table dhcp_acklog 
(
 type varchar(20) not null, 
 ether varchar(20) not null, 
 ip varchar(20), 
 tstamp datetime not null, 
 server varchar(128) not null, 
 gateway varchar(128)
)
partition by key(tstamp)
partitions 96;

create index dhcp_acklog_ether ON dhcp_acklog (ether);
create index dhcp_acklog_ip ON dhcp_acklog (ip);
create index dhcp_acklog_tstamp ON dhcp_acklog (tstamp);
create index dhcp_acklog_tstype ON dhcp_acklog (tstamp,type);

-- Schema definition for TABLE DHCP_CURLEASES
create table dhcp_curleases 
(
 ether varchar(20) not null, 
 ip varchar(20) not null, 
 tstamp datetime not null
);

create index dhcp_curleases_ether ON dhcp_curleases (ether);
create unique index dhcp_curleases_ip ON dhcp_curleases (ip);
create index dhcp_curleases_tstamp ON dhcp_curleases (tstamp);

-- Schema definition for TABLE DHCP_HOST_OPTIONS
create table dhcp_host_options 
(
 host varchar(120) not null, 
 config varchar(250) not null, 
 tstamp datetime not null
);

create index dhcp_host_options_h ON dhcp_host_options (host);
create unique index dhcp_host_options_hc ON dhcp_host_options (host, config);

-- Schema definition for TABLE DHCP_LASTACK
create table dhcp_lastack 
(
 type varchar(20) not null, 
 ether varchar(20) not null, 
 ip varchar(20), 
 tstamp datetime not null, 
 server varchar(128)
);

create unique index dhcp_lastack_ether ON dhcp_lastack (ether);
create index dhcp_lastack_ip ON dhcp_lastack (ip);
create index dhcp_lastack_tstamp ON dhcp_lastack (tstamp);
create index dhcp_lastack_type ON dhcp_lastack (type);

-- Schema definition for TABLE DHCP_SUBNET_OPTIONS
create table dhcp_subnet_options 
(
 subnet varchar(20) not null, 
 config varchar(250) not null, 
 tstamp datetime not null
);

create index dhcp_subnet_options_s ON dhcp_subnet_options (subnet);

-- Schema definition for TABLE DNS_A
create table dns_a 
(
 zone varchar(120) not null, 
 ttl integer DEFAULT 0 not null, 
 name varchar(120) not null, 
 address varchar(120) not null, 
 mtime datetime not null, 
 ctime datetime not null, 
 dynamic integer DEFAULT 0 not null, 
 visible varchar(1) DEFAULT 1 not null
);

create index dns_a_address ON dns_a (address);
create index dns_a_name ON dns_a (name);
create unique index dns_a_nameaddr ON dns_a (name, address);
create index dns_a_zone ON dns_a (zone);

-- Schema definition for TABLE DNS_AAAA
create table dns_aaaa
(
 zone varchar(120) not null, 
 ttl integer DEFAULT 0 not null, 
 name varchar(120) not null, 
 address varchar(120) not null, 
 mtime datetime not null, 
 ctime datetime not null, 
 dynamic integer DEFAULT 0 not null, 
 visible varchar(1) DEFAULT 1 not null
);

create index dns_aaaa_address ON dns_aaaa (address);
create index dns_aaaa_name ON dns_aaaa (name);
create unique index dns_aaaa_nameaddr ON dns_aaaa (name, address);
create index dns_aaaa_zone ON dns_aaaa (zone);

-- Schema definition for TABLE DNS_CNAME
create table dns_cname 
(
 zone varchar(120) not null, 
 ttl integer DEFAULT 0 not null, 
 name varchar(120) not null, 
 address varchar(120) not null, 
 mtime datetime not null, 
 ctime datetime not null, 
 dynamic integer DEFAULT 0 not null, 
 visible varchar(1) DEFAULT 1 not null
);

create index dns_cname_address ON dns_cname (address);
create unique index dns_cname_name ON dns_cname (name);
create index dns_cname_zone ON dns_cname (zone);

-- Schema definition for TABLE DNS_MX
create table dns_mx 
(
 zone varchar(120) not null, 
 ttl integer DEFAULT 0 not null, 
 name varchar(120) not null, 
 priority integer not null, 
 address varchar(120) not null, 
 mtime datetime not null, 
 ctime datetime not null, 
 dynamic integer DEFAULT 0 not null, 
 visible varchar(1) DEFAULT 1 not null
);

create index dns_mx_address ON dns_mx (address);
create index dns_mx_name ON dns_mx (name);
create unique index dns_mx_nap ON dns_mx (name, address, priority);
create index dns_mz_zone ON dns_mx (zone);

-- Schema definition for TABLE DNS_NS
create table dns_ns 
(
 zone varchar(120) not null, 
 ttl integer DEFAULT 0 not null, 
 name varchar(120) not null, 
 address varchar(120) not null, 
 mtime datetime not null, 
 ctime datetime not null, 
 dynamic integer DEFAULT 0 not null, 
 visible varchar(1) DEFAULT 1 not null
);

create index dns_ns_addr ON dns_ns (address);
create index dns_ns_name ON dns_ns (name);
create unique index dns_ns_zna ON dns_ns (zone, name, address);

-- Schema definition for TABLE DNS_PTR
create table dns_ptr 
(
 zone varchar(120) not null, 
 ttl integer DEFAULT 0 not null, 
 name varchar(120) not null, 
 address varchar(120) not null, 
 mtime datetime not null, 
 ctime datetime not null, 
 dynamic integer DEFAULT 0 not null, 
 namesort integer DEFAULT 0 not null, 
 visible varchar(1) DEFAULT 1 not null
);

create index dns_ptr_address ON dns_ptr (address);
create index dns_ptr_name ON dns_ptr (name);
create index dns_ptr_zone ON dns_ptr (zone);
create unique index dns_ptr_zonename ON dns_ptr (name, zone);

-- Schema definition for TABLE DNS_SOA
create table dns_soa 
(
 zone varchar(120) not null, 
 ttl integer DEFAULT 0 not null, 
 server varchar(120) not null, 
 contact varchar(120) not null, 
 serial integer not null, 
 refresh integer not null, 
 retry integer not null, 
 expire integer not null, 
 minttl integer not null, 
 mtime datetime not null, 
 ctime datetime not null, 
 dynamic integer DEFAULT 0 not null, 
 visible varchar(1) DEFAULT 1 not null,
 signzone varchar(1) DEFAULT 0 not null
);

create unique index dns_soa_zone ON dns_soa (zone);

-- Schema definition for TABLE DNS_SRV
create table dns_srv 
(
 zone varchar(120) not null, 
 ttl integer DEFAULT 0 not null, 
 name varchar(120) not null, 
 priority integer not null, 
 weight integer not null, 
 port integer not null, 
 address varchar(120) not null, 
 mtime datetime not null, 
 ctime datetime not null, 
 dynamic integer DEFAULT 0 not null, 
 visible varchar(1) DEFAULT 1 not null
);

create index dns_srv_address ON dns_srv (address);
create index dns_srv_name ON dns_srv (name);
create unique index dns_srv_napp ON dns_srv (name, address, port);
create index dns_srv_zone ON dns_srv (zone);

-- Schema definition for TABLE DNS_TXT
create table dns_txt 
(
 zone varchar(120) not null, 
 ttl integer DEFAULT 0 not null, 
 name varchar(120) not null, 
 txt varchar(250) not null, 
 mtime datetime not null, 
 ctime datetime not null, 
 dynamic integer DEFAULT 0 not null, 
 visible varchar(1) DEFAULT 1 not null
);

create index dns_txt_name ON dns_txt (name);
create index dns_txt_zone ON dns_txt (zone);

-- Schema definition for TABLE DOMAINS
create table domains 
(
 domain varchar(120) not null, 
 description varchar(120) not null
);

create unique index domains_domain ON domains (domain);

-- Schema definition for TABLE ETHERS
create table ethers 
(
 name varchar(120) not null, 
 ether varchar(20) not null
);

create unique index ethers_ether ON ethers (ether);
create index ethers_name ON ethers (name);

-- Schema definition for TABLE HOSTS
create table hosts 
(
 host varchar(120) not null, 
 domain varchar(120) not null, 
 type varchar(20) not null, 
 owner varchar(20) not null, 
 modifiedby varchar(20), 
 description varchar(250), 
 location varchar(250), 
 ctime datetime not null, 
 mtime datetime not null, 
 adminlock integer, 
 purge_date datetime, 
 purge_date_updated datetime, 
 admin_comments varchar(250), 
 vulnstatus varchar(50)
);

create index hosts_adminlock ON hosts (adminlock);
create index hosts_domain ON hosts (domain);
create unique index hosts_host ON hosts (host);
create index hosts_owner ON hosts (owner);
create index hosts_pd ON hosts (purge_date);
create index hosts_pdu ON hosts (purge_date_updated);
create index idx_h_d ON hosts (description);
create index idx_h_l ON hosts (location);

-- Schema definition for TABLE IP_ALLOC
create table ip_alloc 
(
 ip varchar(20) not null, 
 subnet varchar(20), 
 type varchar(20) not null, 
 host varchar(120)
);

create index ip_alloc_host ON ip_alloc (host);
create unique index ip_alloc_ip ON ip_alloc (ip);
create index ip_alloc_iphost ON ip_alloc (ip, host);
create index ip_alloc_st ON ip_alloc (subnet, type);
create index ip_alloc_subnet ON ip_alloc (subnet);
create index ip_alloc_type ON ip_alloc (type);

-- Schema definition for TABLE LAST_TOUCH_ETHER
create table last_touch_ether 
(
 ether varchar(12) not null, 
 tstamp datetime not null
);

create unique index lte_ether ON last_touch_ether (ether);
create index lte_tstamp ON last_touch_ether (tstamp);

-- Schema definition for TABLE LAST_TOUCH_HOST
create table last_touch_host 
(
 host varchar(120) not null, 
 tstamp datetime not null
);

create unique index lth_host ON last_touch_host (host);
create index lth_tstamp ON last_touch_host (tstamp);

-- Schema definition for TABLE LAST_TOUCH_IP
create table last_touch_ip 
(
 ip varchar(15) not null, 
 tstamp datetime not null
);

create unique index lti_ip ON last_touch_ip (ip);
create index lti_tstamp ON last_touch_ip (tstamp);

-- Schema definition for TABLE LOG
create table log 
(
 tstamp datetime not null, 
 app varchar(100) not null, 
 function varchar(100), 
 action varchar(100), 
 userid varchar(20), 
 owner varchar(20), 
 host varchar(128), 
 ether varchar(20), 
 address varchar(128), 
 status varchar(20), 
 msg varchar(500)
) partition by key(tstamp)
partitions 16;

create index log_host ON log (host);
create index log_tu ON log (tstamp, userid);

-- Schema definition for TABLE MAC_BLOCK
create table mac_block 
(
 vlan integer, 
 ether varchar(20) not null, 
 updateflag integer
);

create index mac_block_ether ON mac_block (ether);
create index mac_block_uf ON mac_block (updateflag);
create index mac_block_vlan ON mac_block (vlan);

-- Schema definition for TABLE MENU_ADMIN_OPTIONS
create table menu_admin_options 
(
 optionname varchar(40) not null primary key, 
 label varchar(100)
);

-- Schema definition for TABLE MENU_DHCP_OPTIONS
create table menu_dhcp_options 
(
 optionname varchar(40) not null primary key,
 label varchar(100)
);

-- Schema definition for TABLE METADATA
create table metadata 
(
 host varchar(120) not null, 
 fieldgroup varchar(200) not null, 
 fieldname varchar(200) not null, 
 value varchar(4000), 
 ctime datetime, 
 mtime datetime
);

create index metadata_fgroup_fname_idx ON metadata (fieldgroup, fieldname);
create unique index metadata_pk ON metadata (host, fieldgroup, fieldname);
create index metadata_value_idx ON metadata (value);

-- Schema definition for TABLE METADATA_FIELDS
create table metadata_fields 
(
 fieldgroup varchar(200) not null, 
 fieldname varchar(200) not null, 
 type varchar(20), 
 helper varchar(100), 
 re_valid_value varchar(600), 
 re_invalid_value varchar(600), 
 re_valid_hostname varchar(600), 
 re_invalid_hostname varchar(600), 
 editpriv varchar(200), 
 viewpriv varchar(200), 
 description varchar(200), 
 label varchar(100), 
 example varchar(300), 
 ctime datetime, 
 mtime datetime, 
 netdb_visible varchar(1), 
 netdb_editable varchar(1)
);

create unique index metadata_fields_pk ON metadata_fields (fieldgroup, fieldname);

-- Schema definition for TABLE QUOTA
create table quota 
(
 owner varchar(20) not null, 
 quota integer not null
);

create index quota_owner ON quota (owner);

-- Schema definition for TABLE SUBNETS
create table subnets 
(
 subnet varchar(20) not null, 
 description varchar(120) not null, 
 mask varchar(20) not null, 
 vlan varchar(20), 
 gateway varchar(15) not null, 
 template varchar(50), 
 notes varchar(2000)
);

create unique index subnets_subnet ON subnets (subnet);

-- Schema definition for TABLE SWITCH_VLANS
create table switch_vlans 
(
 switch varchar(100) not null, 
 tstamp datetime not null, 
 snmpver integer, 
 vlan integer
);

create index switch_vlans_switch ON switch_vlans (switch);
create index switch_vlans_tstamp ON switch_vlans (tstamp);

-- Schema definition for TABLE VLANS
create table vlans 
(
 vlan integer not null primary key, 
 name varchar(50) not null, 
 notes varchar(2000)
);


-- Schema definition for TABLE IGNORED_ETHERS
create table ignored_ethers
(
 ether varchar(20) not null,
 tstamp datetime not null
);

create unique index ignored_ethers_eth ON ignored_ethers (ether);
create index ignored_ethers_ts ON ignored_ethers (tstamp);




drop table if exists last_ping_ip;
create table last_ping_ip 
(
 ip varchar(15) not null, 
 source varchar(50) not null,
 ether varchar(20),
 tstamp datetime not null
);

create unique index lpi_ipse ON last_ping_ip (ip,source,ether);
create index lpi_ether ON last_ping_ip (ether);
create index lpi_tstamp ON last_ping_ip (tstamp,ip);


create table last_nmap_ip 
(
 ip varchar(15) not null, 
 source varchar(50) not null,
 tstamp datetime not null,
 results text
);

create unique index lni_ips ON last_nmap_ip (ip,source);
create index lni_tstamp ON last_nmap_ip (tstamp,ip);




