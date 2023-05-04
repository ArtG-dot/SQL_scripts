
/*get current date*/
select GETDATE(), GETUTCDATE(),CURRENT_TIMESTAMP;
select SYSDATETIME(), SYSUTCDATETIME(),SYSDATETIMEOFFSET();



select DATENAME(week,getdate()), isdate('17520228')



/*convertation*/
declare @dt datetime = getdate();
declare @tab table (style int, present varchar(50));

insert into @tab values 
(100, CONVERT(varchar(50),@dt,100))
,(101, CONVERT(varchar(50),@dt,101))
,(102, CONVERT(varchar(50),@dt,102))
,(103, CONVERT(varchar(50),@dt,103))
,(104, CONVERT(varchar(50),@dt,104))
,(105, CONVERT(varchar(50),@dt,105))
,(106, CONVERT(varchar(50),@dt,106))
,(107, CONVERT(varchar(50),@dt,107))
,(108, CONVERT(varchar(50),@dt,108))
,(109, CONVERT(varchar(50),@dt,109))
,(110, CONVERT(varchar(50),@dt,110))
,(111, CONVERT(varchar(50),@dt,111))
,(112, CONVERT(varchar(50),@dt,112))
,(113, CONVERT(varchar(50),@dt,113))
,(114, CONVERT(varchar(50),@dt,114))
,(120, CONVERT(varchar(50),@dt,120))
,(121, CONVERT(varchar(50),@dt,121))
,(126, CONVERT(varchar(50),@dt,126))
,(127, CONVERT(varchar(50),@dt,127))
,(130, CONVERT(varchar(50),@dt,130))
,(131, CONVERT(varchar(50),@dt,131))
,(999, FORMAT(@dt, 'yyyy-MM-dd hh:mm:ss', 'en-US'))
,(999, FORMAT(@dt, 'ddMMyyy', 'en-US'))

select * from @tab;