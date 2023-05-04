select * from temp2;
create table temp3 (id int,
guid_num uniqueidentifier default newsequentialid());
select * from temp3;

insert into temp3(id) values (3)
go 10

truncate table temp3;

begin tran my_test_tran_3
insert into temp3(id,guid_num) values (3,NEWID());
commit tran my_test_tran_3

begin tran my_test_tran_4
insert into temp3(id,guid_num) values (3,NEWID());
commit work 

go 100



declare @tab1 table (id int);
insert into @tab1 values (1);
