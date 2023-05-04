--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------
/*инфо о ленточных устройствах*/
select * from sys.dm_io_backup_tapes;
																															
/*имена каждого из общих дисковых устройств для кластера (MSFC); если сервер не кластеризован, то возвращается пустой набор
набор дисков в кластерном ресурсе, только они могу быть использованы для кластера*/
select * from sys.dm_io_cluster_shared_drives
select * from sys.dm_io_cluster_valid_path_names --c 2014

/*каждая строка, это ожидающий запрос ввода/вывода*/
select * from sys.dm_io_pending_io_requests

select * from sys.dm_db_file_space_usage

SELECT SUM(user_object_reserved_page_count)*8 as usr_obj_kb,
SUM(internal_object_reserved_page_count)*8 as internal_obj_kb,
SUM(version_store_reserved_page_count)*8 as version_store_kb,
SUM(unallocated_extent_page_count)*8 as freespace_kb,
SUM(mixed_extent_page_count)*8 as mixedextent_kb
FROM sys.dm_db_file_space_usage


/*статистика ввода/вывода для файлов данных и файлов журнала*/
select * FROM sys.dm_io_virtual_file_stats (db_id('tempdb'),NULL) AS vfs --параметры: db_id, file_id

/*общая информация о сервисах*/
select distinct last_startup_time from sys.dm_server_services where last_startup_time is not null


--------------------------------------------------------------------------------------------
-----------------------------------------Statistics-----------------------------------------
--------------------------------------------------------------------------------------------
/*статистика I/O для файлов (данных и журнала) Ѕƒ:
sample_ms - время с запуска компьютера, в мс
num_of_reads - кол-во чтений для файла
num_of_bytes_read - кол-во чтений в байтах для файла 
io_stall_read_ms - общее время задержек чтения, в мс
num_of_writes - число записей в файл
num_of_bytes_written - число записей в байтах для файла
io_stall_write_ms - общее время задержек записи, в мс
io_stall - общее время задержек для операций I/O
size_on_disk_bytes - размер файла в байтах*/
SELECT 
    ReadLatency = CASE WHEN num_of_reads = 0 THEN 0 ELSE (io_stall_read_ms / num_of_reads) END, --средняя задержка чтения
	WriteLatency = CASE WHEN num_of_writes = 0 THEN 0 ELSE (io_stall_write_ms / num_of_writes) END, --средняя задержка записи
	Latency = CASE WHEN (num_of_reads = 0 AND num_of_writes = 0) THEN 0 ELSE (io_stall / (num_of_reads + num_of_writes)) END, --средняя задержка I/O
	AvgBPerRead = CASE WHEN num_of_reads = 0 THEN 0 ELSE (num_of_bytes_read / num_of_reads) END, --среднее кол-во байт при чтении
	AvgBPerWrite = CASE WHEN io_stall_write_ms = 0 THEN 0 ELSE (num_of_bytes_written / num_of_writes) END, --среднее кол-во байт при записи
	AvgBPerTransfer = CASE WHEN (num_of_reads = 0 AND num_of_writes = 0) THEN 0 ELSE ((num_of_bytes_read + num_of_bytes_written) / (num_of_reads + num_of_writes)) END, --среднее кол-во байт операции I/O
	LEFT (mf.physical_name, 2) AS Drive,
	DB_NAME (vfs.database_id) AS DB,
	mf.physical_name,
	mf.type_desc fl_type,
	 convert(smalldatetime,dateadd(s,-1*vfs.sample_ms/1000, getdate())) dt_srv_start
	, (select convert(smalldatetime,last_startup_time) from sys.dm_server_services where servicename = 'SQL Server (MSSQLSERVER)') dt_svc_start_
	--vfs.*
FROM sys.dm_io_virtual_file_stats (NULL,NULL) AS vfs --параметры: db_id, file_id
JOIN sys.master_files AS mf
	ON vfs.database_id = mf.database_id
	AND vfs.file_id = mf.file_id
WHERE 1 = 1
and DB_NAME (vfs.database_id) not in ('master','model', 'msdb','ReportServer','ReportServerTempDB','SSISDB')
and DB_NAME (vfs.database_id) not in ('min_test','test') 
--vfs.file_id = 2 -- log files
ORDER BY WriteLatency DESC
--order by drive



--------------------------------------------------------------------------------------------
-------------------------------------------Errors-------------------------------------------
--------------------------------------------------------------------------------------------
/*информация по ошибкам операций IO из журнала логов*/
if OBJECT_ID('tempdb..#log_num') is not null drop table #log_num;
if OBJECT_ID('tempdb..#log_info') is not null drop table #log_info;

/*кол-во журналов с логами*/
create table #log_num (num int, dt datetime, size int)
insert into #log_num exec master..xp_enumerrorlogs 1

create table #log_info (dt datetime, process varchar(20), log_text varchar(4000))
declare @cnt int = 0

while (@cnt < = (select max(num) from #log_num))
begin
	insert into #log_info exec master..xp_readerrorlog @cnt,1 -- 1 - журнал SQL Server,2 - журнал SQL Server Agent
	set @cnt += 1
end

	/*общая инфа по долгим операциям записи*/
	select * from #log_info t 
	where 1=1
	and t.log_text like '%I/O requests taking longer than%'
	--and t.log_text like '%I/O%'
	and dt > DATEADD(DAY, -2, GETDATE())
	order by 1 desc, 2 desc

	/*группировка по файлам и дате*/
	select cast(dt as date) dt
	, substring(t.log_text, CHARINDEX('[',t.log_text,0),CHARINDEX(']',t.log_text,0)-CHARINDEX('[',t.log_text,0) +1) fl_nm, count(*) cnt
	, sum(cast(substring(t.log_text, CHARINDEX('encountered',t.log_text,0)+12,CHARINDEX('occurrence(s)',t.log_text,0)-CHARINDEX('encountered',t.log_text,0) -13) as int)) sm
	from #log_info t 
	where 1=1
	and t.log_text like '%I/O requests taking longer than%'
	and dt > DATEADD(DAY, -2, GETDATE())
	group by cast(dt as date), substring(t.log_text, CHARINDEX('[',t.log_text,0),CHARINDEX(']',t.log_text,0)-CHARINDEX('[',t.log_text,0) +1)
	order by 1 desc, 4 desc

	/*группировка по файлам*/
	select substring(t.log_text, CHARINDEX('[',t.log_text,0),CHARINDEX(']',t.log_text,0)-CHARINDEX('[',t.log_text,0) +1) fl_nm, count(*) cnt
	, sum(cast(substring(t.log_text, CHARINDEX('encountered',t.log_text,0)+12,CHARINDEX('occurrence(s)',t.log_text,0)-CHARINDEX('encountered',t.log_text,0) -13) as int)) sm
	from #log_info t 
	where 1=1
	and t.log_text like '%I/O requests taking longer than%'
	and dt > DATEADD(DAY, -1, GETDATE())
	--and dt > '2019-03-29'
	group by substring(t.log_text, CHARINDEX('[',t.log_text,0),CHARINDEX(']',t.log_text,0)-CHARINDEX('[',t.log_text,0) +1)
	order by 3 desc

	/*группировка по дискам*/
	select  cast(dt as date) dt, sum(cast(substring(t.log_text, CHARINDEX('encountered',t.log_text,0)+12,CHARINDEX('occurrence(s)',t.log_text,0)-CHARINDEX('encountered',t.log_text,0) -13) as int)) sm
	, substring(t.log_text, CHARINDEX('[',t.log_text,0)+1,1) dsk_nm
	from #log_info t 
	where t.log_text like '%I/O requests taking longer than%'
	and dt > DATEADD(DAY, -1, GETDATE())
	--and substring(t.log_text, CHARINDEX('[',t.log_text,0)+1,1) in ('M','N','G', 'F')
	group by cast(dt as date), substring(t.log_text, CHARINDEX('[',t.log_text,0)+1,1)
	order by 1 desc

drop table #log_num;
drop table #log_info;



select * from sys.dm_db_session_space_usage
