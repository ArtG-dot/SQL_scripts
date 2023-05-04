--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------

-----------------------------------------------------------------
/*общая информация: 
размер журнала, файлы журнала, свободное пространство в журнале*/
-----------------------------------------------------------------

--файлы данных и файлы лога для текущей БД
select * from sys.database_files
	where type = 1 --файлы журнала

/*общая информация по использованию лог-файла для всех БД: размер журнала транзакций, % заполнения*/
DBCC SQLPERF (logspace)

/*общая информация по использованияю журнала для теущей БД*/
select db_name(database_id) db_nm, * from sys.dm_db_log_space_usage

select * from sys.dm_db_log_info (db_id()) --c 2016 SP2
select * from sys.dm_db_log_stats (db_id()) --c 2016 SP2


/*инфо по I/O операциям с файлами БД*/
select db_name() db_nm, f.type_desc, s.* from sys.dm_io_virtual_file_stats(DB_ID(),NULL) s
	right join sys.database_files f on f.file_id = s.file_id



---------------------------------------------
/*детальная информация по структуре журнала:
кол-во VLF, занятые/свободные VLF*/
---------------------------------------------

/*информация по структуре журнала транзакций. количество строк это кол-во VLF.
RecoveryUnitID
FileId - id физического файла журнала
FileSize
StartOffset
FSeqNo
Status - статус VLF (0 - можно использовать повторно, 2 - нельзя использовать повторно)
Parity
CreateLSN
*/
DBCC LOGINFO ('TEST') --в скобках имя БД
DBCC LOGINFO (TEST)


SELECT name AS 'Database Name', total_vlf_count AS 'VLF count'   --c 2016 SP2
FROM sys.databases AS s   
CROSS APPLY sys.dm_db_log_stats(s.database_id)   



--------------------------------------------------
/*детальная информация по записям в журнале:
записи из активной части журнала по транзакциям */

--!!! ВСЕ ФУНКЦИИ НЕДОКУМЕНТИРОВАНЫ !!!
--------------------------------------------------

--просмотр активной части журнала: на одну транзакцию несколько записей
--1. вариант с DMF 
select * from sys.fn_dblog(NULL,NULL)
	--where [Transaction ID] = '0000:00001d26' --по какой транзакции искать

--2. вариант с DBCC
DBCC LOG('TEST',-1) WITH TABLERESULTS, NO_INFOMSGS;


-- просмотр данных из бэкапа журнала
SELECT *
FROM fn_dump_dblog
(NULL,NULL,N'DISK',1,N'E:\backups\AdventureWorks2012_05222013.trn', 
DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT, 
DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,
DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,
DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,
DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,
DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,
DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT, 
DEFAULT);


--просмотр страниц журнала
DBCC TRACEON (3604, -1)
--DBCC PAGE ( {'dbname' | dbid}, filenum, pagenum [, printopt={0|1|2|3} ])
DBCC PAGE (TEST, 2, 0, 2)	--страница 0 в файле 2, FileID = 2 это файл журнала
DBCC TRACEOFF (3604, -1)



--------------------------------------------------------------------------------------------
-----------------------------------------Maintaince-----------------------------------------
--------------------------------------------------------------------------------------------

DBCC SQLPERF ('sys.dm_os_latch_stats' , CLEAR) --Resets the latch statistics
DBCC SQLPERF ('sys.dm_os_wait_stats' , CLEAR) --Resets the wait statistics

---------------------------
/*работа с файлом журнала*/
---------------------------

/*удаление вторичного (secondary) файла журнала из БД*/
ALTER DATABASE new REMOVE FILE dfdfsact_1_Log

/*м.б. ошибка: file cannot be removed because it is not enpty
в этом случае можно попробовать:
1. сделать бэкап БД и журнала
2. перезапустить SQL Server */



/*shrink transaction log для нескольких БД*/
--НЕ РАБОТАЕТ, т.к. команду DBCC SHRINKFILE нужно вып в контексте каждой БД
declare @log_size int; 
declare @tbl_nm table (db_nm varchar(50));
declare @str nvarchar(4000);

set @log_size = 100; --до какого размера сжимать
insert @tbl_nm values --перечисляем для каких БД
('Credit'),
('Arch'), 
('test')

if (object_id('tempdb..#temp') is not null) drop table #temp;
create table #temp (db_nm varchar(50), log_size_mb float, log_space_used_procent float, log_status int);

insert into #temp exec ('DBCC SQLPERF(logspace)');
if exists (select db_nm from #temp where db_nm in (select db_nm from @tbl_nm)
	and log_size_mb > @log_size and 100*@log_size/log_size_mb > log_space_used_procent)
begin
	DECLARE @db_nm nvarchar(50);

	DECLARE cur CURSOR
	FOR select db_nm from #temp where db_nm in (select db_nm from @tbl_nm)
		and log_size_mb > @log_size and 100*@log_size/log_size_mb > log_space_used_procent

	OPEN cur;
	FETCH NEXT FROM cur INTO @db_nm;

	WHILE @@fetch_status = 0
	BEGIN
		
		if (select count(*) from sys.master_files where database_id = db_id(@db_nm) and type_desc = 'LOG') = 1 
		begin
			SET @str = 'DBCC SHRINKFILE(' + (select name from sys.master_files where database_id = db_id(@db_nm) and type_desc = 'LOG') + ',' + cast(@log_size as varchar(10)) + ');' 
			EXEC (@str);
			--print @str
		end

		FETCH NEXT FROM cur INTO @db_nm;
	END

	CLOSE cur;
	DEALLOCATE cur;
end



/*shrink transaction log с проверкой*/
declare @log_size int = 100; --до какого размера сжимать
declare @str nvarchar(4000);

if exists (select * from sys.dm_db_log_space_usage where total_log_size_in_bytes/1024/1024 > @log_size*2 and used_log_space_in_bytes/1024/1024 < @log_size)
begin
	if (select count(*) from sys.master_files where database_id = db_id() and type_desc = 'LOG') = 1
	begin
		declare @fl_nm varchar(50);
		select @fl_nm = name from sys.master_files where database_id = db_id() and type_desc = 'LOG'

		DBCC SHRINKFILE(@fl_nm, @log_size);
	end
	else THROW 500001, 'multiple trn log files', 1;
end
else print 'no need trn log file shrink for ' + db_name()



----------------------------------------------------------------------------------------------------------------------------------------

/*настройка Delayed Durability (с 2014)
все транзакции записываются в журнал (компонент Log Manager через Log Buffer (60кб)), после этого идет уведомление клиенту, что транзакция завершилась успешно.
запись на диск происходит асинхронно за счет либо Lazy Writer либо CHECKPOINT
для сокращения задержек записи на диск [wait_type] = N'WRITELOG' можно включить параметр Delayed Durability
данные будут записываться в лог только при заполнении Log Buffer
это сокращает время ожидания записи в журнал,но есть риск потери транзакций (!!!)
можно применять на всей БД либо на отдельно транзакции: ALTER DATABASE TT SET DELAYED_DURABILITY = ALLOWED /   BEGIN TRANSACTION t ... COMMIT TRANSACTION t WITH (DELAYED_DURABILITY = ON)
выгодно кога в БД много коротких транзакций (например вставка/изменение построчно)
*/
use test;
ALTER DATABASE test SET RECOVERY full
DBCC SQLPERF ('sys.dm_os_latch_stats' , CLEAR)
DBCC SQLPERF ('sys.dm_os_wait_stats' , CLEAR) 

drop table if exists tbl, #temp;

CREATE TABLE dbo.tbl (
      a INT IDENTITY PRIMARY KEY
    , b INT
    , c CHAR(2000));


SELECT t.[file_id], t.num_of_writes, t.num_of_bytes_written
INTO #temp
FROM sys.dm_io_virtual_file_stats(DB_ID(), NULL) t

DECLARE @WaitTime BIGINT
      , @WaitTasks BIGINT
      , @StartTime DATETIME = GETDATE()
      , @LogRecord BIGINT = (
              SELECT COUNT_BIG(*)
              FROM sys.fn_dblog(NULL, NULL)
          )

	SELECT @WaitTime = wait_time_ms
			, @WaitTasks = waiting_tasks_count
	FROM sys.dm_os_wait_stats
	WHERE [wait_type] = N'WRITELOG'

	DECLARE @i INT = 1
	WHILE @i < 50000 BEGIN
		INSERT INTO dbo.tbl (b, c)  VALUES (@i, 'text')
		SELECT @i += 1
	END

	SELECT elapsed_seconds = DATEDIFF(MILLISECOND, @StartTime, GETDATE()) * 1. / 1000
			, wait_time = (wait_time_ms - @WaitTime) / 1000.
			, waiting_tasks_count = waiting_tasks_count - @WaitTasks
			, log_record = (
				SELECT COUNT_BIG(*) - @LogRecord
				FROM sys.fn_dblog(NULL, NULL)
			)
	FROM sys.dm_os_wait_stats
	WHERE [wait_type] = N'WRITELOG'

	SELECT [file] = FILE_NAME(o.[file_id])
			, num_of_writes = t.num_of_writes - o.num_of_writes
			, num_of_mb_written = (t.num_of_bytes_written - o.num_of_bytes_written) * 1. / 1024 / 1024
	FROM #temp o
	CROSS APPLY sys.dm_io_virtual_file_stats(DB_ID(), NULL) t
	WHERE o.[file_id] = t.[file_id]
	order by num_of_mb_written desc

--результат до
elapsed_seconds		wait_time		waiting_tasks_count		log_record
18.557000			10.515000		49999					331807

file			num_of_writes		num_of_mb_written
TEST_Log		50196				196.53125000000
TEST_Data		139					98.11718750000


ALTER DATABASE test SET DELAYED_DURABILITY = FORCED

--результат после
elapsed_seconds		wait_time		waiting_tasks_count		log_record
13.423000			1.561000		5						331094

file			num_of_writes		num_of_mb_written
TEST_Log		2511				128.43359375000
TEST_Data		269					94.75781250000
	

----------------------------------------------------------------------------------------------------------------------------------------

/*Для восстановления БД из копии журнала транзакций до определённого момента времени или до конкретной транзакции, вам необходимо:

Определить LSN (Log Sequence Number) для этой транзакции
Преобразовать LSN в формат, который используется в конструкции WITH STOPBEFOREMARK = ‘<mark_name>’, 
например значение 00000070:00000011:0001 должно быть переведено в формат 112000000001700001
Восстановите полную резервную копию БД и всю цепочку резервных копий журнала транзакций до нужной транзакции 
с помощью конструкции WITH STOPBEFOREMARK = ‘<mark_name>’ , где укажите идентификатор нужной транзакции.
*/

RESTORE LOG AdventureWorks2012
FROM
    DISK = N'E:\backups\AW2012_05232013.trn'
WITH
    STOPBEFOREMARK = 'lsn:112000000001700001',
    NORECOVERY;