--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------

select * from sys.databases; --общая информация
select database_id, name, state_desc, user_access_desc, recovery_model_desc,
owner_sid, create_date, compatibility_level, is_read_only
from sys.databases
where name not in ('master','model','tempdb', 'msdb');

select * from sys.master_files

exec sp_helpdb; --размеры всех БД 
/*размер БД это сумма размеров файлов данных (.mdf, .ndf) + файлы журнала (.ldf)*/

/*размер БД*/
select db.name
, sum(iif(mf.type=0,mf.size,0))*8./1024/1024 'data size (GB)'
, cast(sum(iif(mf.type=1,mf.size,0))*8./1024/1024 as decimal(10,2))'log size (GB)'
from sys.databases db
left join sys.master_files mf
	on db.database_id = mf.database_id
--where substring(mf.physical_name,1,1) = 'K'
where db.name not in ('master','model','tempdb', 'msdb','ReportServer','ReportServerTempDB','SSISDB')
group by db.name
--having sum(iif(mf.type=1,mf.size,0))*8/1024 > 500
order by db.name



/*детальная информация*/
select db.database_id 'id'
, db.name
, db.state_desc
, db.user_access_desc
, db.recovery_model_desc
, mf.file_id
, mf.type_desc
, mf.name
, mf.physical_name
, substring(mf.physical_name,1,1) 'disc'
, mf.state_desc
, cast(mf.size as bigint)*8/1024/1024 'size (GB)'
, IIF(mf.max_size = -1, 'unlimit', cast(mf.max_size/1024/1024*8 as varchar(50))) 'max_size (GB)'
, mf.growth*8/1024 'growth (MB)'
, mf.is_percent_growth
, mf.is_read_only
from sys.databases db
left join sys.master_files mf
	on db.database_id = mf.database_id
--where substring(mf.physical_name,1,1) = 'K'
where 1 = 1
and db.name not in ('master','model', 'msdb','ReportServer','ReportServerTempDB','SSISDB','dhw'/*,'KP','SMP','bufferSMP'*/)

order by db.database_id,mf.type_desc desc,mf.file_id


