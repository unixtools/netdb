alter table dns_a add column etime datetime;
alter table dns_aaaa add column etime datetime;
alter table dns_cname add column etime datetime;
alter table dns_mx add column etime datetime;
alter table dns_ns add column etime datetime;
alter table dns_ptr add column etime datetime;
alter table dns_srv add column etime datetime;
alter table dns_txt add column etime datetime;
alter table dns_spf add column etime datetime;

alter table dns_soa add column last_size integer default 0;
alter table dns_soa add column last_lines integer default 0;
update dns_soa set last_size=0;
update dns_soa set last_lines=0;
alter table dns_soa modify column last_size integer default 0 not null;
alter table dns_soa modify column last_lines integer default 0 not null;

