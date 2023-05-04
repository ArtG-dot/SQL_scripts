exec sp_help 'tmp_proc_1'
exec sp_helptext 'tmp_proc_1'

alter proc tmp_proc_1
@par1 int out,
@par2 int out
as
begin
set nocount on;
set @par1 = @par1 + 1;
set @par2 = @par1*10;
print @par1 ;
print @par2 ;
insert into temp values (@par1);
insert into temp values (@par2);
end;

declare @x int;
declare @y int;
set @x=1;
set @y = 2;
exec tmp_proc_1 @x , @y ;
print @x;
print @y;
select * from temp;
truncate table temp;
select * from temp5;

select top  (4) with ties * from temp5 order by state desc; 


select @@VERSION;

select 
	PROVIDER_ID,
	EXT_DATA,
	ID
from ap_providers pr;

sys.sp_addextendedproperty ???

exec sp_helptext 'test_proc';
exec sp_helptext 'tmp_proc_1';

drop table temp7;

select * from temp2;
insert into temp2 values (7,3),(4,3),(4,2),(5,4);
select * from inserted; 

create trigger tmp_trg on temp2
after insert
as 
begin
	select * from inserted;
end;

select * from sys.objects where name = 'tmp_trg'

select * from sys.objects where type = 'TR'


select * from ap_version_info