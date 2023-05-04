--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------
/*по умолчанию каталог для отдельного экземпляра:
C:\Program Files\Microsoft SQL Server\MSSQL13.<instance_name>\MSSQL
для экземпляра по умолчанию: C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL
БД по умолчанию лежат в каталоге: C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\DATA

*/


/*общая информация о сервисах*/
select * from sys.dm_server_services
select * from sys.dm_server_registry

/*настройки SQL Server*/
select * from sys.configurations
select * from sys.syslogins

-------
/*RAM*/
-------
select * from sys.dm_os_sys_memory
select * from sys.dm_os_process_memory

select * from sys.configurations where name like '%memory%'

select * from sys.dm_os_memory_clerks
			
			select top 10 type, sum(pages_kb)/1024 'MB'
			from sys.dm_os_memory_clerks
			group by type
			order by 2 desc


			SELECT session_id, requested_memory_kb / 1024 as RequestedMemMb, 
			granted_memory_kb / 1024 as GrantedMemMb, text
			FROM sys.dm_exec_query_memory_grants qmg
			CROSS APPLY sys.dm_exec_sql_text(sql_handle)

			SELECT TOP 5 DB_NAME(database_id) AS [Database Name],
			COUNT(*) * 8/1024.0 AS [Cached Size (MB)]
			FROM sys.dm_os_buffer_descriptors WITH (NOLOCK)
			GROUP BY DB_NAME(database_id)
			ORDER BY [Cached Size (MB)] DESC


/*информация о буффер пул: каждая строка это закешированная страница хранящаяся в buffer pool*/
select * from sys.dm_os_buffer_descriptors


/*отображение либо изменение (с параметрами) основных настроек сервера*/
exec sp_configure

/*настройка опции максимального кол-ва потоков*/
sp_configure 'max worker threads'
go

/*процессы на сервере*/
select * from sys.sysprocesses --SPID <= 50 - системные

/*исп ф-цию SERVERPROPERTY ( propertyname ) для информации на */
select 
	SERVERPROPERTY ('ComputerNamePhysicalNetBIOS') 'HostName' --имя хоста либо активного плеча кластера
	, SERVERPROPERTY ('MachineName') 'MachineName' --имя хоста либо либо имя кластера (виртуального сервера)
	, SERVERPROPERTY ('ServerName') 'ServerName' --имя хоста\[имя экземпляра]
	, SERVERPROPERTY ('ProcessID') 'ProcessID' --ID процесса на хосте (PID sqlservr.exe)
	, ISNULL(SERVERPROPERTY('InstanceName'),'MSSQLSERVER') 'InstanceName' --имя экземпляра
	, SERVERPROPERTY ('Collation') 'Collation' --Collation на уровне экземпляра (для отдельно БД может отличаться)
	, SERVERPROPERTY ('Edition') 'Edition' --редакция SQL Server
	, case SERVERPROPERTY ('IsClustered') --находится ли экземпляр в отказоустойчивом кластере
		when 0 then 'Not Clustered'
		when 1 then 'Clustered'
	end 'IsClustered'
	, case SERVERPROPERTY ('IsSingleUser') --находится ли экземпляр в состоянии single-user 
		when 0 then 'Not single user'
		when 1 then 'Single user'
	end 'IsSingleUser'
	, case SERVERPROPERTY ('IsFullTextInstalled') --находится ли экземпляр в состоянии single-user 
		when 0 then 'FullText not installed'
		when 1 then 'FullText installed'
	end 'IsFullTextInstalled'
	, LEFT(@@VERSION,68) SQLServerVersion --версия SQL Server
	, SERVERPROPERTY ('ErrorLogFileName') 'ErrorLogFileName' --
	, SERVERPROPERTY ('ProductLevel') 'ProductLevel' --версия релиза
	, SERVERPROPERTY ('ResourceVersion') 'ResourceVersion' --
	, @@VERSION SQLServerVersionFull

select 
	HOST_NAME() 'ClientName' --имя рабочей станции
	, HOST_ID() 'Host id' -- id рабочей станции
	, @@SERVERNAME 'ServerName\InstanceName' --имя сервера(кластера)(\имя экземпляра) 
	, @@SERVICENAME 'InstanceName' --имя экземпляра
	, DB_NAME() 'Current DB name' --имя текущей БД
	, PROGRAM_NAME()
	, current_user
	, SUSER_ID()
	, SUSER_NAME()
--	, SUSER_SID()
	, SUSER_SNAME()
	, SYSTEM_USER
	, USER

/*инфо о текущем пользователе*/
select 
	SUSER_ID()
	, @@SPID
	, SUSER_NAME()
--	, SUSER_SID()
	, SUSER_SNAME()
	, SYSTEM_USER
	, USER
	, USER_ID()
	, USER_NAME()
	, USER_SID()
	, SESSION_USER
	, SESSION_ID() -- для 2016


	
------------------------------------------------------------------------------------------------
-----------------------------------------все БД на сервере--------------------------------------
------------------------------------------------------------------------------------------------
select * from sys.databases;
select database_id,name,state,state_desc, user_access_desc,recovery_model_desc from sys.databases;


--------------------------------------------------------------------------------------------------
-----------------------------------------размер файлов БД-----------------------------------------
--------------------------------------------------------------------------------------------------
exec sp_helpdb; --размеры всех БД 
/*размер БД это сумма размеров файлов данных (.mdf, .ndf) + файлы журнала (.ldf)*/

exec sp_helpdb 'Analitica'; --по отдельной БД (размер + все файлы БД)
/* db_size = data_file (.mdf, .ndf) + log_file (.ldf) (сумма всех файлов БД)*/

select * from sys.sysfiles; 
/* все размеры файлов БД (size, growth) - это кол-во страниц (по 8 КБ)
т.е. реальный размер файла = size*8(KB)*/

select * from sys.filegroups;
/*список всех файловых групп*/



select 
	DB_NAME() 'DB name'
	, sum(convert(bigint,size))*8/1024 'db size (MB)' --размер текущей БД
	, sum(convert(bigint,case when status & 64 = 0 then size else 0 end))*8/1024 'data files size (MB)' -- & (побитовое И)
	, sum(convert(bigint,case when status & 64 <> 0 then size else 0 end))*8/1024 'log files size (MB)'
  from dbo.sysfiles



  /*список БД, страницы которых хранятся в buffer pool*/
  select db_name(database_id), count(*)/1024/1024*8192 'MB'
  from sys.dm_os_buffer_descriptors
  group by db_name(database_id)
  order by 2 desc

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
and db.name not in ('master','model', 'msdb','ReportServer','ReportServerTempDB','SSISDB','dhw')
--and db.name  in ('tempdb','KP')
--and mf.type_desc = 'LOG'


--and substring(mf.physical_name,1,1) in ('J','K')
order by db.database_id,mf.type_desc desc,mf.file_id


