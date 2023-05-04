--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------

--------------------
/*host information*/
--------------------

/*информация о кластере*/
select * from sys.dm_os_cluster_nodes
select * from sys.dm_os_cluster_properties

/*общая инфо от хосте*/
exec xp_msver
 

 /*общие параметры сервера*/
/*info по ќ— на хосте
max_workers_count - число используемых рабочих потоков (не путать worker и worker thread !!!)
каждый новый коннект использует отдельный рабочий поток*/
select * from sys.dm_os_sys_info
select * from sys.dm_os_sys_memory
select * from sys.dm_os_tasks
select * from sys.dm_os_threads

/*общая информация об ќ—*/
select * from sys.dm_os_windows_info

--------------------
/*дисковая система*/
--------------------
exec xp_fixeddrives --размер свободного пространства дисков
select * from sys.dm_io_cluster_shared_drives --кластерные диски
select * from sys.dm_io_cluster_valid_path_names --c 2014, кластерные диски

-------
/*RAM*/
-------
select * from sys.dm_os_sys_memory
/*информация о буффер пул: каждая строка это закешированная страница хранящаяся в buffer pool*/
select * from sys.dm_os_buffer_descriptors


--счетчики производительности
select * from sys.dm_os_performance_counters


-------------------------------
/*общая информация о сервисах*/
-------------------------------
select * from sys.dm_server_services
select servicename, service_account, process_id, last_startup_time
from sys.dm_server_services





/*общая информация из реестра о настройках SQL Server*/
/* если есть доступ до регистра
HKLM\Software\Microsoft\Microsoft SQL Server\Instance Names\SQL - список экземпляров SQL Server на хосте*/

exec xp_cmdshell 'reg query HKLM\Software\Microsoft\Microsoft SQL Server\Instance Names\SQL'  -- не проверял!!!!
exec master.sys.xp_instance_regenumvalues -- не проверял!!!!

select * from sys.dm_server_registry

/*настройки SQL Server*/
select * from sys.configurations
select * from sys.syslogins

/*отображение либо изменение (с параметрами) основных настроек сервера*/
exec sp_configure

/*настройка опции максимального кол-ва потоков*/
sp_configure 'max worker threads'
go



/*процессы на сервере*/
select * from sys.sysprocesses --SPID <= 50 - системные

select 
	HOST_NAME() 'ClientName' --имя рабочей станции
	, HOST_ID() 'Host id' -- id рабочей станции
	, @@SERVERNAME 'ServerName\InstanceName' --имя сервера(кластера)(\имя экземпляра) 
	, @@SERVICENAME 'InstanceName' --имя экземпляра
	, DB_NAME() 'Current DB name' --имя текущей Ѕƒ
	, PROGRAM_NAME()
	, '*************'
	, current_user
	, USER_ID()
	, USER_NAME()
	, SUSER_ID()
	, SUSER_NAME()
	, SUSER_SID()
	, SUSER_SNAME()

select 
	SERVERPROPERTY ('ComputerNamePhysicalNetBIOS') 'HostName' --имя хоста либо активного плеча кластера
	, SERVERPROPERTY ('MachineName') 'MachineName' --имя хоста либо либо имя кластера (виртуального сервера)
	, SERVERPROPERTY ('ServerName') 'ServerName' --имя сервера\имя экземпляра
	, ISNULL(SERVERPROPERTY('InstanceName'),'MSSQLSERVER') 'InstanceName' --имя экземпляра
	, SERVERPROPERTY ('ProcessID') 'ProcessID' --ID процесса на хосте (PID sqlservr.exe)
	, case SERVERPROPERTY ('IsClustered') --находится ли экземпляр в отказоустойчивом кластере
	when 0 then 'Not Clustered'
	when 1 then 'Clustered'
	end 'IsClustered'
	, case SERVERPROPERTY ('IsSingleUser') --находится ли экземпляр в состоянии single-user 
	when 0 then 'Not single user'
	when 1 then 'Single user'
	end 'IsSingleUser'
	, LEFT(@@VERSION,68) SQLServerVersion --версия SQL Server
	, SERVERPROPERTY ('Edition') 'Edition' --редакция SQL Server
	, SERVERPROPERTY ('ProductLevel') 'ProductLevel' --версия релиза
	, SERVERPROPERTY ('ResourceVersion') 'ResourceVersion' --
	, @@VERSION SQLServerVersionFull