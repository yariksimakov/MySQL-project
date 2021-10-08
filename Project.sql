-- my project, i use public_services
-- drop database if exists public_services;
-- create database public_services;
-- use public_services;


/*
 This database is designed to store user profile and information about contacting government services.
*/




create table users (
	id SERIAL primary key,
	surname varchar(50),
	name varchar(50),
	patronymic varchar(50) comment 'for residents of russia',
	email varchar(50) unique,
	password_hash varchar(100),
	telephone BIGINT unsigned unique,
	index users_surname_name_idx(surname, name)
);


create table profiles (
	id serial primary key,
	users_id bigint unsigned not null,
	gender enum('f', 'm'),
	birthday date,
	snils bigint(11) unsigned unique,
	individual_tax_number bigint(12) unsigned unique,
	created_at datetime default now(),
	updated_at datetime on update now(),
	foreign key (users_id) references users(id)
)comment 'Table of personal data of users';

alter table profiles add constraint profiles_chk_1  check (created_at < updated_at);



create table users_family (
	profiles_id bigint unsigned not null unique,
	married enum('yes', 'no'),
	wife varchar(50),
	telefone_wife int unsigned,
	children int unsigned default 0 comment 'quantity',
	father varchar(50),
	telefone_father int unsigned,
	mother varchar(50),
	telefone_mother int unsigned,
	foreign key (profiles_id) references profiles (id)
)comment 'Everything about marital status';

alter table users_family change wife spouse varchar(50);

create table passports (
	profiles_id bigint unsigned not null primary key,
	series int unsigned unique,
	numbers int unsigned unique,
	issued_by_whom varchar(100),
	constraint passports_fk_1 
	foreign key (profiles_id) references profiles (id)
)comment 'Main document';



-- ---------------------------------------------------------------------------------



create table order_services (
	id SERIAL,
	users_id bigint unsigned,
	price double(10,2),
	description_order varchar(250),
	created_at datetime default now(),
	updated_at datetime on update current_timestamp,
	foreign key (users_id) references users(id)
)comment 'Order table, contains order data';



alter table order_services add column metadata JSON;
alter table order_services add constraint order_services_chk_1 check (created_at < updated_at);

create table transport_value (
	order_id bigint unsigned not null primary key,
	town varchar(50) not null,
	police_department varchar(100) not null,
	description_statement varchar(255) not null,
	foreign key (order_id) references order_services(id)
)comment = 'Police report table';

alter table transport_value change order_id order_id bigint unsigned not null;
create index transport_value_order_id_idx on transport_value(order_id);
alter table transport_value drop primary key;



create table health_cares (
	order_id bigint unsigned not null primary key,
	town varchar(50) not null,
	hospital_name varchar(200) not null,
	which_doctor varchar(100) not null,
	description_problem varchar(255),
	constraint healthy_cares_fk_1
	foreign key (order_id) references order_services(id)
)comment 'Doctor appointment table';

alter table health_cares modify order_id bigint unsigned not null;
create index health_cares_order_id_idx on health_cares(order_id);
alter table health_cares drop primary key;



create table tax_finances (
	order_id bigint unsigned not null primary key,
	town varchar(50) not null,
	tax_office varchar(200) not null,
	description_statement varchar(255) not null,
	foreign key (order_id) references order_services(id)
)comment = 'For inquiries to the tax office';

create index tax_finances_order_id_idx on tax_finances(order_id);
alter table tax_finances drop primary key;


create table passport_viz (
	order_id bigint unsigned not null primary key,
	place_birth varchar(100) not null,
	citizenship varchar(50),
	town varchar(50) not null,
	passport_office varchar(100) not null,
	description_statement varchar(255),
	foreign key (order_id) references order_services(id)
)comment 'Obtaining citizenship or visa';


create index passport_viz_order_id_idx on passport_viz(order_id);
alter table passport_viz drop primary key;



create table education (
	order_id bigint unsigned not null primary key,
	town varchar(50) not null,
	education_institution varchar(100) not null,
	description_statement varchar(255),
	foreign key (order_id) references order_services(id)
)comment 'to apply for admission to an educational institution';

create index education_order_id_idx on education(order_id);
alter table education drop primary key;


create table family (
	order_id bigint unsigned not null primary key,
	town varchar(50) not null,
	registry_office varchar(100) not null,
	description_statement varchar(150),
	foreign key (order_id) references order_services(id)
)comment 'Marriage registration table';

create index family_order_id_idx on family(order_id);
alter table family drop primary key;



create table photos (
	users_id bigint unsigned not null,
	order_services_id bigint unsigned not null,
	foreign key (users_id) references users(id),
	foreign key (order_services_id) references order_services(id)
)comment 'Some operations require a photo';


-- ------------------------------------------------------------------------------------


select * from users;
select id from profiles where created_at < updated_at ;
update profiles set created_at = birthday where birthday > created_at;
select os.id from order_services os join profiles p on os.users_id = p.users_id  and p.created_at < os.created_at;
select surname, name, email, os.id, price from users u 
join order_services os on u.id = users_id;


create or replace view users_order_id_price as select surname, name, email, os.id, price from users u 
join order_services os on u.id = users_id;



update users_family set wife = null where married = 'no';
update users_family set telefone_wife = null where spouse = null;
select surname, name, us.telephone, married, spouse, telefone_wife  from users us
join profiles p on users_id = us.id
join users_family uf on profiles_id = p.id;



create or replace view personal_data as select surname, name, birthday, us.telephone, married, spouse, telefone_wife  
from users us
join profiles p on users_id = us.id
join users_family uf on profiles_id = p.id;



-- ---------------------------------------------------------------------------





delimiter //

create trigger order_services_check_create before insert on order_services
for each row 
begin
	if (new.users_id = null or new.price = null) then 
		signal sqlstate '23000' set message_text = 'error in the inserted value, value must not equal null';
	end if;
end//


create procedure insert_order_services (in user_id bigint unsigned, in price double, description varchar(250))
begin
	declare continue handler for sqlstate '23000' 
	set @error = 'insert values type error';
	insert into order_services (users_id, price, description_order) values (user_id, price, description);
	if @error is not null then
		select @error;
	end if;	
end//



create trigger order_services_check_update before update on order_services
for each row 
begin 
	if (new.users_id = null or new.price = null) then
		signal sqlstate '23000' set message_text = 'error in the update value, value must not equal null';
	end if;
end//



create procedure  basic_data_user_op (in person_id int) 
begin
	select surname, name, gender, any_value(birthday) as birthday, group_concat(os.id separator ' - ') as operations, group_concat(os.price separator ' - ') as price,
	group_concat(date(os.created_at) separator '; ') as date_oparations, count(os.id) as count_operation
	from profiles p
	join order_services os on p.users_id = os.users_id
	join users u on u.id = p.users_id 
	where os.users_id = person_id group by os.users_id;
end//

delimiter ;






explain	select surname, name, gender, any_value(birthday) as birthday, group_concat(os.id separator ' - ') as operations, group_concat(os.price separator ' - ') as price,
	group_concat(date(os.created_at) separator '; ') as date_oparations, count(os.id) as count_operation
	from profiles p
	join order_services os on p.users_id = os.users_id
	join users u on u.id = p.users_id 
	where os.users_id = 205 group by os.users_id;

explain	select surname, name, gender, any_value(birthday) as birthday, group_concat(os.id separator ' - ') as operations, group_concat(os.price separator ' - ') as price,
	group_concat(date(os.created_at) separator '; ') as date_oparations, count(os.id) as count_operation
	from profiles p
	join order_services os on p.users_id = os.users_id
	join users u on u.id = p.users_id 
	group by os.users_id having os.users_id = 205;

