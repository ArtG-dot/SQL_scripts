/*создание БД*/

USE [master]
GO

create database [sample] 
on primary	--ниже перечисляется список файлов для файловой группы PRIMARY
	(name = N'Sample_Data1',				--логическое имя
	filename = N'C:\sample\sample.mdf',		--физ. имя и расположение
	size = 8mb,								--исходный размер файла
	maxsize = unlimited,					--максимальный размер
	filegrowth = 3mb),						--шаг прироста
filegroup FG1	--файлы для файловой группы FG1
	(name = N'Sample_Data2',
	filename = N'C:\sample\sample.ndf',
	size = 8mb,
	maxsize = 20mb,
	filegrowth = 3mb),
filegroup Documents contains filestream default	--файлы для файловой группы Documents (тип filestream), эта файловая группа для BLOB файлов по умолчанию
	(name = N'Documents',
	filename = N'C:\sample\sampleDcuments')
log on 
	(name = N'Sample_Log',
	filename = N'C:\sample\sample.ldf',
	size = 8mb,
	maxsize = 100mb, 
	filegrowth = 3mb)
go


/*создание contained database*/
--A partially contained database allows you to implement uncontained features that cross the database boundary
--настройка сервера
	EXEC sp_configure 'contained database authentication', 1;
	RECONFIGURE;
--создание БД
	USE master;
	DROP DATABASE IF EXISTS ImportSales1;
	CREATE DATABASE ImportSales1 CONTAINMENT = PARTIAL; --SQL Server does not support fully contained databases (?)










--------------------------------------------------------------------------------------------
------------------------------------------DB-status-----------------------------------------
--------------------------------------------------------------------------------------------

DBCC CHECKDB

/*смена статуса БД*/
USE master
GO

ALTER DATABASE TEST COLLATE Cyrillic_General_CI_AS 


select d.name, d.create_date, d.compatibility_level, d.user_access_desc, d.is_read_only, d.state_desc, d.recovery_model_desc   from sys.databases d

/*перевод в офлайн*/
ALTER DATABASE min_test SET OFFLINE 
	WITH NO_WAIT  
	-- ROLLBACK IMMEDIATE откат незавершенных транзакций немедленно
	-- ROLLBACK AFTER 999 [SECONDS] откат тарнзакции через 999 секунд
	-- NO_WAIT если требуется завершение или откат транзакции, то запрос потерпит неудачу
/*перевод в онлайн*/
ALTER DATABASE min_test SET ONLINE WITH ROLLBACK IMMEDIATE

/*перевод в однопользовательский режим*/
ALTER DATABASE Credit SET SINGLE_USER WITH ROLLBACK IMMEDIATE
/*перевод в многопользовательский режим*/
ALTER DATABASE Credit SET MULTI_USER WITH ROLLBACK IMMEDIATE
/*перевод в режим подключения пользователей ролей db_owner, sysadmin*/
ALTER DATABASE Credit SET RESTRICTED_USER WITH ROLLBACK IMMEDIATE

/*перевод в режим только для чтения*/
ALTER DATABASE Credit SET READ_ONLY WITH ROLLBACK IMMEDIATE
/*перевод в режим для чтения и записи*/
ALTER DATABASE Credit SET READ_WRITE WITH ROLLBACK IMMEDIATE

/*смена модели восстановления */
ALTER DATABASE test SET RECOVERY SIMPLE --FULL, BULK_LOGGED, SIMPLE


/*смена настройки параметризации*/
 --Forced
ALTER DATABASE AdventureWorks2012 SET PARAMETERIZATION FORCED
	--Simple
ALTER DATABASE AdventureWorks2012 SET PARAMETERIZATION SIMPLE


/*включение Change Tracking на уровне БД*/
ALTER DATABASE [PL] SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 3 DAYS);



/*изменение статуса нескольких БД*/
use master
go



ALTER DATABASE база_данных
{ ADD FILE <указание_на_файл> [TO FILEGROUP наименование]
| ADD LOG FILE <указание_на_файл>
| REMOVE FILE логическое_имя_файла
| ADD FILEGROUP имя_группы
| REMOVE FILEGROUP имя_группы
| MODIFY FILE <указание_на_файл>
| MODIFY FILEGROUP имя_группы свойство_группы }
где <указание_на_файл> =
(NAME = ’логическое_имя_файла’,
FILENAME = ’физическое_имя_файла’
[, SIZE = размер]
[, MAXSIXE = {максимальный_размер | UNLIMITED} ]
[, FILEGROWTH = шаг_приращения_размера [Mb | Kb | %] )



/*вариант 1*/
select name, state_desc into #tab from sys.databases
where name in (
	'ReportServer'
	,'ReportServerTempDB'
	)
	order by name

select * from #tab

DECLARE @db_nm nvarchar(50),
		@str nvarchar(4000)

DECLARE cur CURSOR
FOR
	select name from #tab

OPEN cur;

FETCH NEXT
FROM cur
INTO @db_nm;

WHILE @@fetch_status = 0
BEGIN
	SET @str = 'ALTER DATABASE ' + @db_nm + ' SET OFFLINE WITH NO_WAIT'

	--print @str
	EXEC (@str);

	FETCH NEXT
	FROM cur
	INTO @db_nm;
END

CLOSE cur;

DEALLOCATE cur;

select name, state_desc from sys.databases
where name in (
	'ReportServer'
	,'ReportServerTempDB'
	)
	order by name

/*вариант 2*/
execute sp_msforeachdb 
	'if ''?'' IN (''test'',''Diamant'', ''min_test'')
	exec (''ALTER DATABASE [?] SET RECOVERY SIMPLE'')'

--------------------------------------------------------------------------------------------
------------------------------------------DB-Files------------------------------------------
--------------------------------------------------------------------------------------------
/*детальная информация*/
select db.database_id 'id'
, db.name db_nm
, db.state_desc
, db.user_access_desc
, db.recovery_model_desc
, mf.file_id
, mf.type_desc
, mf.name fl_nm
, mf.physical_name
, substring(mf.physical_name,1,1) 'disc'
, mf.state_desc
, mf.size/1024/1024*8 'size (GB)'
, IIF(mf.max_size = -1, 'unlimit', cast(mf.max_size/1024/1024*8 as varchar(50))) 'max_size (GB)'
, mf.growth
, mf.is_percent_growth
, mf.is_read_only
, mf.*
from sys.databases db
left join sys.master_files mf
	on db.database_id = mf.database_id
where db.name  = 'tempdb' --not in  ('master','model',/*'tempdb',*/ 'msdb','ReportServer','ReportServerTempDB','SSISDB')
order by db.database_id,mf.type_desc desc,mf.file_id


/*добавляем новую файловую группу*/
ALTER DATABASE TEST 
	ADD FILEGROUP FG_2019;


/*удаляем файловую группу*/
ALTER DATABASE TEST 
	REMOVE FILEGROUP FG_2019;


/*добавляем новый файл данных в файловую группу*/
ALTER DATABASE Ccard 
ADD FILE (
		NAME = 'Fg_2019' --логич. имя
		, FILENAME = 'U:\data.sql\Fg_2019.ndf' --распопложение файла
		, SIZE = 10000 MB --начальный размер
		, FILEGROWTH = 100 MB --прирост
		, MAXSIZE = 50 GB --максимальный размер
	) TO FILEGROUP FG_2019; --в какую файловую группу


/*удаление файла из БД*/
DBCC SHRINKFILE (db_name_1_Log, EMPTYFILE); --очистить файл данных
GO
ALTER DATABASE db_namenew REMOVE FILE db_name_1_Log --удаляем файл данных
GO

/*изменить существующий файл*/ 

ALTER DATABASE tempdb MODIFY FILE 
	(NAME = tempdev
	, FILENAME = 'F:\TempDB\tempdb_1.ndf'
)
GO

/*перенос файла в другую директорию*/
1. перевести БД в офлайн режим
2. вручную переместить файл
3. выполнить операцию ALTER DATABASE <db_nm> MODIFY FILE указав новый путь до файла
4. перевети БД в онлайн режим


/*сжатие файла до указанного размера (в MB)*/
use db_namenew
GO

select name, physical_name, size*8/1024 'size (MB)', iif(max_size = -1,-1,max_size*8/1024) 'max_size (MB)', growth*8/1024 'growth (MB)',*
from sys.database_files

DBCC SHRINKFILE (N'db_name_Log' , 500)
GO

--------------------
/*настройка tempdb*/
--------------------
/*меняем настройки файлов(например расположение) на работающей tempdb, настройки менятся в системных представлениях, но реально работает состарыми файлами
перезагружаем сервер, создаются новые файлы в новой директории
удаляем старые файлы
*/

ALTER DATABASE tempdb MODIFY FILE 
	(NAME = tempdb_2
	, FILENAME = 'J:\TempDB\tempdb_2.ndf'
)
GO
ALTER DATABASE tempdb MODIFY FILE 
	(NAME = tempdb_3
	, FILENAME = 'G:\TempDB\tempdb_3.ndf'
)
GO
ALTER DATABASE tempdb MODIFY FILE 
	(NAME = tempdb_4
	, FILENAME = 'H:\TempDB\tempdb_4.ndf'
)
GO
ALTER DATABASE tempdb MODIFY FILE 
	(NAME = tempdb_5
	, FILENAME = 'K:\TempDB\tempdb_5.ndf'
)
GO
ALTER DATABASE tempdb MODIFY FILE 
	(NAME = tempdb_6
	, FILENAME = 'L:\TempDB\tempdb_6.ndf'
)
GO
ALTER DATABASE tempdb MODIFY FILE 
	(NAME = tempdb_7
	, FILENAME = 'N:\TempDB\tempdb_7.ndf'
)
GO
ALTER DATABASE tempdb MODIFY FILE 
	(NAME = tempdb_8
	, FILENAME = 'M:\TempDB\tempdb_8.ndf'
)
GO
ALTER DATABASE tempdb MODIFY FILE 
	(NAME = temp_log
	, FILENAME = 'G:\TempDB\tempdb_log.ndf'
)
GO



------------------------------
/*отсоединение БД от сервера*/
------------------------------
use master
exec sp_detach_db 'TEST' --БД файлы БД сохраняются, в отличии от DROP

/*присоединение БД (из файлов)*/
create database TEST on
(filename ='c:\TEST_data.mdf'),
(filename ='c:\TEST_log.ldf')
for attach;


--Изменение владельца базы данных
sp_changedbowner [ [@loginname=] ‘имя_пользователя’



--Переименование базы данных:
sp_renamedb [@old_name=] ‘старое_имя’, [@new_name=] ‘новое_имя’


DBCC SHRINKDATABASE (‘имя_БД’, [‘процент’] [, NOTRUNCATE | TRUNCATEONLY])
DBCC SHRINKFILE (‘имя_файла’, [‘конечный_размер’] [, EMPTYFILE | NOTRUNCATE | TRUNCATEONLY ])







