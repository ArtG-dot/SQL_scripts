/*
Во время операции бэкапирования БД данные записываются на физическое устройство резервного копирования (physical backup device)
Это устройство (backup device) инициализируется при записи на него первой резервной копии (backup) в наборе носителей (media set).
Резервные копии (backups) на наборе из одного или нескольких устройств резервного копирования (backup devices) образуют отдельный набор носителей (single media set).

backup disk - жесткий диск или другое дисковое устройство, кот. содержит 1 или более файлов резервной копии (backup files)
backup file - обычный файл операционной системы (.bak)
physical backup device - лента или файл на диске. Бэкап может быть записан на от 1 до 64 backup device
backup device - логическое имя physical backup device (Server -> Server Objects -> Backup Devices)
media set (набор носителей)- упорядоченный набор носителей резерв. копирования (backup media), ленточных носителей (tapes) или файлов на диске (disk files), 
	кот. используют опред. тип и колв-о устройств рез. копир (backup devices)
media family
backup set (резервный набор данных) - содержит резервную копию, полученную в результате отдельной успешной операции резервного копирования. 
	backup set это и есть бэкап (резервная копия)
*/

--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------
use msdb;
go

select * from master.sys.backup_devices --все действующие backup device
select * from msdb..backupfile; -- строка для каждого файла данных или журнала, по кот. был проведен бэкап (столбцы описывают конфигурацию файла на момент бэкапа)
select * from msdb..backupfilegroup; --строка для каждой файловой группы во время бэкапа
select * from msdb..backupmediafamily; --строка для каждого семейства носителей
select * from msdb..backupmediaset; -- строка для каждого резервного набора носителей 
select * from msdb..backupset; -- строка для каждого резервного набора данных
--вып ХП sp_delete_backuphistory для чистки истории по бэкапам


-- Очистка списка Backup Sets и Media Sets в таблицах dbo.backupset и dbo.backupmediaset соответственно
EXEC sp_delete_backuphistory '02/02/2012' -- удаляет все записи старше даты
GO
EXEC sp_delete_database_backuphistory 'AdventureWorks2008' -- удаляет все записи о резервном копировании базы данных
GO

-- Просмотр Backup Sets в Backup Devices
RESTORE HEADERONLY 
FROM DISK = N'\\f$\Database\bd1Simple.bak'
GO




---------------------------------------Бэкапы всех БД на сервере---------------------------------------
select
	SERVERPROPERTY ('Servername') 'Server'
	, s.server_name
	, s.database_name
	, s.recovery_model
	, s.user_name
	, s.backup_start_date
	, s.backup_finish_date
	, s.expiration_date
	, case s.type 
	when 'D' then 'Database'
	when 'L' then 'Log'
	end 'type'
	, s.backup_size
	, s.name
	, f.logical_device_name
	, f.physical_device_name
	, s.description
from msdb..backupmediafamily f
inner join msdb..backupset s
	on f.media_set_id = s.media_set_id
where s.database_name = 'msdb'
order by /*s.backup_set_id,*/ s.database_name,  s.backup_finish_date desc

--------------------------------Бэкапы всех файлов данных и журналов на экземпляре--------------------------------
select
	SERVERPROPERTY ('Servername') 'Server'
	, s.server_name
	, s.database_name
	, s.user_name
	, bf.filegroup_name
	, bf.file_number
	, case bf.file_type 
	when 'D' then 'Database'
	when 'L' then 'Log'
	else '???'
	end 'type'
	, bf.backed_up_page_count
	, bf.page_size
	, bf.file_size
	, bf.logical_name
	, bf.physical_name
	, bf.state_desc
	, bf.backup_size
	, s.backup_start_date
	, s.backup_finish_date
	, s.expiration_date
	, s.name
from msdb..backupfile bf
inner join msdb..backupset s
	on bf.backup_set_id = s.backup_set_id
inner join msdb..backupmediafamily f
	on f.media_set_id = s.media_set_id
order by s.backup_set_id; 

---------------------------------------Последние бэкапы всех БД на сервере---------------------------------------
select
	SERVERPROPERTY ('Servername') 'Server'
	, s.server_name
	, s.database_name
	, s.recovery_model
	, s.user_name
	, s.backup_start_date backupmediafamily
	, s.backup_finish_date
	, s.expiration_date
	, case s.type 
	when 'D' then 'Database'
	when 'L' then 'Log'
	else '???'
	end 'type'
	, s.backup_size
	, s.name
	, f.logical_device_name
	, f.physical_device_name
	, s.description
from msdb..backupmediafamily f
inner join msdb..backupset s
	on f.media_set_id = s.media_set_id
where s.backup_set_id in (select MAX(backup_set_id) from msdb..backupset group by database_name)
and  s.database_name in (select name from sys.databases) 
order by s.backup_set_id; 


------------------------------------------------------------------------------------------------
---------------------------------------обслуживание бэкапов-------------------------------------
------------------------------------------------------------------------------------------------
/*создание нового Backup Device*/
USE [master]
GO
EXEC master.dbo.sp_addumpdevice  
	@devtype = N'disk'
	, @logicalname = N'bk_test_1' --имя устройства
	, @physicalname = N'I:\бэкап\test_file.bak' --место расположениz файла
GO



/*Просмотор Backup Sets в Backup Devices*/
/*проверка содержания, просмотр заголовков резервных копий */
--Returns a result set containing all the backup header information for all backup sets on a particular backup device in SQL Server.
RESTORE HEADERONLY
	FROM DISK = 'I:\\db\test_Full_2019-01-01.bak' --из Backup File
	--FROM [bk_test]  --из Backup Device
--WITH MEDIANAME = 'aaa' --указываем Media Name
--,FILE = --Backup Set File number



/*создание Full Backup для БД*/
BACKUP DATABASE test 
	--TO DISK = 'I:\KP\test_Full_2019-01-01.bak' --запись бэкапа в Backup File
	TO  [bk_test]  --запись бэкапа на Backup Device
WITH 
NOFORMAT
 , NOINIT --INIT - новые бэкапы перезаписывают старые на носителе, NOINIT - новые бэкапы дозаписываются в конец
 , NOSKIP --SKIP - отключение проверки срока действия и имен бэкапов, NOSKIP - проверка выполняется (например на одном устройстве д.б. одинаковые MEDIANAME)
 , MEDIANAME = 'test_media' --имя Media Set
 --, MEDIADESCRIPTION = 'text' --описание Media Set
 , NAME = N'test-Full Database Backup 3' --имя Backup Set
 --, DESCRIPTION = 'text' --описание Backup Set
 --, NOREWIND --только для ленточного накопителя
 --, NOUNLOAD	--только для ленточного накопителя
 , COMPRESSION --сжатие бэкапа
 , BUFFERCOUNT = --меняя этот параметр можно сократить время бэкапа + DBCC TRACEON (3213, 3605, -1) (для просмотра текущих значений)
 , MAXTRANSFERSIZE = --меняя этот параметр можно сократить время бэкапа + DBCC TRACEON (3213, 3605, -1) (для просмотра текущих значений)
 , STATS = 10
 


 /*создание Differrential Backup для БД*/
 USE AdventureWorks
GO

DECLARE @name_backup_set varchar(max);
SET @name_backup_set = N'AdventureWorks Differential Backup ' + CONVERT(varchar(30),GETDATE(),113) + '.bak';

BACKUP DATABASE [AdventureWorks] 
TO  [backup-device] 
WITH
	DIFFERENTIAL,
	NOFORMAT, 
	NOINIT,  
	MEDIANAME = N'AdventureWorks Media Set',  
	NAME = @name_backup_set, 
	NOSKIP, 
	NOREWIND, 
	NOUNLOAD,  
	STATS = 10
GO


 /*создание Log Backup для БД*/
USE AdventureWorks
GO

DECLARE @name_backup_set varchar(max);
SET @name_backup_set = N'AdventureWorks Log Backup ' + CONVERT(varchar(30),GETDATE(),113) + '.bak';

BACKUP LOG [AdventureWorks] 
TO  [backup-device] 
WITH
	NOFORMAT, 
	NOINIT,  
	MEDIANAME = N'AdventureWorks Media Set',  
	NAME = @name_backup_set, 
	NOSKIP, 
	NOREWIND, 
	NOUNLOAD,  
	STATS = 10
GO





/*создание бэкапов нескольких БД*/
use master;
go 

DECLARE @db_nm nvarchar(50),
		@str nvarchar(4000)

DECLARE cur CURSOR
FOR
	select name from sys.databases 
	where name in (
	'fff'
	,'Credit'
	,'Test'
	)
	order by name

OPEN cur;

FETCH NEXT
FROM cur
INTO @db_nm;

WHILE @@fetch_status = 0
BEGIN
	SET @str = 'BACKUP DATABASE ' + @db_nm + ' TO DISK = N''I:\Crrv_20181212\' + @db_nm + '_' + convert(varchar(8), getdate(), 112) +'.bak''
				WITH NOFORMAT, NOINIT, NAME = N''' + @db_nm + '-Full Database Backup'', SKIP, NOREWIND, NOUNLOAD, COMPRESSION, STATS = 10'
	--print @str
	EXEC (@str);
	--EXECUTE sys.sp_executesql @str

	FETCH NEXT
	FROM cur
	INTO @db_nm;
END

CLOSE cur;

DEALLOCATE cur;






/*восстановление из бэкапа в другую БД*/
RESTORE DATABASE [ggg0130] 
FROM  DISK = N'I:\dfd0130.bak' 
WITH  
FILE = 1,  MOVE N'SMP_Data' TO N'I:\dfdf190130.MDF',  
MOVE N'SMP_Log' TO N'I:\dfdf190130_1.LDF',  
NOUNLOAD,  STATS = 5




--DECLARE @DB nvarchar(100) = DB_NAME(),
--		@SQL nvarchar(4000)

--SET	@SQL = 'BACKUP DATABASE ' + @DB + '
--TO  DISK = N''R:\_backup\' + @DB + '\' + @DB + '_' + convert(varchar(8), getdate(), 112) +'.bak''
--WITH NOFORMAT, NOINIT,  NAME = N''' + @DB + '-Full Database Backup'', SKIP, NOREWIND, NOUNLOAD,  COMPRESSION, STATS = 10'

--EXECUTE sys.sp_executesql @SQL;









DECLARE	@filename varchar(100),
		@cmd varchar(200)

CREATE TABLE #filename
	(
	backupname varchar(100)
	)

INSERT INTO #filename
EXECUTE xp_cmdshell 'dir i:\S\*.bak'

-- Чистим таблицу и оставляем только названия хранимых бекапов SMP
DELETE
FROM	#filename
WHERE	ISNULL(backupname, '') NOT LIKE '% msdb_%.bak'

UPDATE	#filename
SET		backupname = RIGHT(backupname, 17)

-- постоянно будем хранить 3 бекапа: 2 старых и 1 свежий
IF (SELECT COUNT(*) FROM #filename) > 2
BEGIN
	DECLARE delete_backup CURSOR LOCAL FOR
	SELECT	TOP((SELECT COUNT(*) FROM #filename) - 2) backupname
	FROM	#filename
	ORDER BY backupname

	OPEN delete_backup
	
	FETCH NEXT FROM delete_backup
	INTO @filename
	WHILE @@fetch_status = 0
	BEGIN
		SET @cmd = 'del /Q i:\SMP\' + @filename

		EXECUTE xp_cmdshell @cmd

		FETCH NEXT FROM delete_backup
		INTO @filename
	END

	CLOSE delete_backup
	DEALLOCATE delete_backup
END
--ELSE PRINT 'Бекапов мало, удалять не будем'

DROP TABLE #filename


DECLARE @DB nvarchar(100) = DB_NAME(),
		@SQL nvarchar(max)

SET	@SQL = 'BACKUP DATABASE ' + @DB + '
TO  DISK = N''I:\S\' + @DB + '_' + convert(varchar(8), getdate(), 112) +'.bak''
WITH NOFORMAT, NOINIT,  NAME = N''' + @DB + '-Full Database Backup'', SKIP, NOREWIND, NOUNLOAD,  STATS = 10'

EXECUTE sys.sp_executesql @SQL;














 -----------------------------------------------------------------------------------------------------------------------------------------------------
 --для restore tail-log
 backup log TEST
 to disk = 'c:\Backup\TEST_tail_log.log'
 with continue_after_error
 go

 --restore with tail-log
 --1. restore from full backup
 restore database TEST from disk = 'c:\Backup\TEST.bak'
 with NORECOVERY;

 --2. restore tail-log
 restore log TEST from disk = 'c:\Backup\TEST_tail_log.log';
