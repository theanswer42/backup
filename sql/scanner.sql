create table locations(
  location_id varchar(64) not null primary key,
  location_path varchar(1024) not null,
  status varchar(10) not null,
  scanned_at int(11)
);
