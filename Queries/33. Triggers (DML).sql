use sample;
go


select * from temp;
select * from TMP;
select * from hisory;
create table hisory (num int, val char(2), date datetime2 )
create view view_1
as select num,val from temp where price is not null with check option;
select * from view_1;
insert into view_1 values (10,'d7')

drop view view_1;

alter trigger trig_1 on temp
after insert, delete
as begin
	--declare @date datetime2;
	--set @date = getdate();
	--select * from inserted;
	--declare @num int
	--set @num = (select top 1 num from inserted);
	--insert into hisory values (select top 1 num from inserted,select val from inserted, @date);
	insert into hisory select num, val, getdate() from inserted
end;

disable trigger trig_1 on temp
enable trigger trig_1 on temp



/*database-level triggers
создается на уровне БД, а не таблицы
*/


create trigger safety_db
on database
for DROP_TABLE, ALTER_TABLE
as	
	print 'You do not have permission!';
	rollback;


drop table dbo.ttt;
DROP TRIGGER [safety_db] ON DATABASE;



