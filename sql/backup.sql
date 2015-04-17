create table failures(
  path varchar(1024) not null primary key
);
create table backups(
  file_id varchar(64) not null primary key,
  hostname varchar(256) not null,
  filename varchar(1024) not null,
  checksum varchar(64) not null,
  backed_up_at int(11) not null,
  external_id varchar(1024),
  reference_file_id varchar(512)
);
create index backups_checksum on backups(checksum);
