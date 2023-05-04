
--------------------------------------------------------------------------------------------
-----------------------------------------Maintaince-----------------------------------------
--------------------------------------------------------------------------------------------

/*создание индекса*/
create unique clustered index CI_cards_info_full on dbo.cards_info_full ([Дата опердня] , tb_id, [N договора WAY4])
with (fillfactor = 80 --процент заполненности на страницах листового(!) уровня индекса, используется только при операциях создания и перестроения индекса 
	, pad_index = off --приминение значения fillfactor на промежуточных уровнях индекса
	, statistics_norecompute = off --автообновление статистики (вкл/выкл)
	, sort_in_tempdb = off --использование tempdb при постороении индекса, может ускорить построения индекса
	, ignore_dup_key = off
	, drop_existing = off
	, online = off --использование индекса в момент rebuild (wait_at_low_priority)
	, allow_row_locks = on --настройки блокировки на уровне строк
	, allow_page_locks = on --настройки блокировки на уровне страницы 
	, data_compression = [none|page|row] --метод сжатия индекса
	, maxdop = [max degree of paralerism] --параллельная обработка индекса
	) on [primary]; --в какой файловой группе будет располагаться  индекс


create index with drop_existing --позволяет пересоздать CI с изменением ключевых полей, работает быстрее чем drop/create

--по рекомендации Microsoft не нужно rebuild/reorganize если индекс менее 1000 страниц
alter table restr_new_old rebuild

alter index IX_ap_reqwest_REQWEST_ID on ap_reqwest rebuild;
alter index IX_ap_reqwest_CLIENT_ID on ap_reqwest rebuild with (fillfactor = 80);
alter index IX_ap_reqwest_CLIENT_ID on ap_reqwest reorganize with (fillfactor = 80);
DBCC DBREINDEX('old',' ',90)




--удаляем все некластер индексы
select distinct t.name, i.name from sys.tables t
left join sys.indexes i
	on i.object_id = t.object_id
where i.index_id > 1
and t.name <> 'sysdiagrams'

DECLARE @i_nm VARCHAR(50);
DECLARE @t_nm VARCHAR(50);
DECLARE @str VARCHAR(4000);

DECLARE cur CURSOR
FOR
select distinct t.name, i.name from sys.tables t
left join sys.indexes i
	on i.object_id = t.object_id
where i.index_id > 1
and t.name <> 'sysdiagrams';

OPEN cur;

FETCH NEXT
FROM cur
INTO @t_nm, @i_nm;

WHILE @@fetch_status = 0
BEGIN
	SET @str = 'drop index [' + @i_nm + '] on ' + @t_nm
	--print @str
	EXEC (@str);

	FETCH NEXT
	FROM cur
	INTO @t_nm, @i_nm;
END

CLOSE cur;

DEALLOCATE cur;

select distinct t.name, i.name from sys.tables t
left join sys.indexes i
	on i.object_id = t.object_id
where i.index_id > 1
and t.name <> 'sysdiagrams'




/*
index fragmentation (external) - логическая и физическая упорядоченность не совпадают на уровне листьев в индексе, 
т.е. номера страниц на листовом уровне идут не в отсортированном порядке (возрастания)


операция REBUILD создает новый индекс в файле и удаляет старый; т.о. для этой операции требуется минимум такой же объем места, какой занимаетстарый индекс;
данная операция проходит как одна большая транзакция и также требует аналогичного места в журнале


операция REORGANIZE меняет местами соседние страницы на листовом уровне, приводя все страницы в отсортированный вид
данная операция проходит как множество системных транзакций

если планируется перестроение кластерного индекса:
нужно ли отключать/удалять некластерные???
влечет ли перестроение кластерного перестроение всех некластерных???

*/


/*index size and fragmentation statistics
последний параметр - уровень детализации: NULL/LIMITED -> SAMPLED -> DETAILED*/
select * from sys.dm_db_index_physical_stats(db_id(),OBJECT_ID('TMP_PORTFOLIO'),NULL,NULL,NULL);
select * from sys.dm_db_index_physical_stats(db_id(),OBJECT_ID('TMP_PORTFOLIO'),NULL,NULL,'LIMITED');
select * from sys.dm_db_index_physical_stats(db_id(),OBJECT_ID('TMP_PORTFOLIO'),NULL,NULL,'SAMPLED');
select * from sys.dm_db_index_physical_stats(db_id(),OBJECT_ID('TMP_PORTFOLIO'),NULL,NULL,'DETAILED');

DBCC SHOWCONTIG(...) --можно посмотреть фрагментацию индекса

	--Rebuild all indexes (note this method locks the tables while the indexes are being rebuilt)
	DECLARE @TableName varchar(255);
	DECLARE @IndexName varchar(255);
	DECLARE TableCursor CURSOR FOR
	
	SELECT  t.name 'table_name',  i.name 'index_name'
	FROM 
	sys.tables t
	left join sys.indexes i
	on i.object_id = t.object_id
	left join sys.dm_db_index_physical_stats (db_id('table1'),117575457,NULL,NULL,NULL) ifs
	on ifs.object_id = t.object_id
	and ifs.index_id = i.index_id
	WHERE 1 = 1
	and ifs.index_type_desc <> 'HEAP'
	and ifs.alloc_unit_type_desc = 'IN_ROW_DATA'
	and ifs.avg_fragmentation_in_percent > 30;

	OPEN TableCursor
	FETCH NEXT FROM TableCursor INTO @TableName,@IndexName
	WHILE @@FETCH_STATUS = 0

	BEGIN
	
	
		ALTER INDEX @IndexName ON @TableName REBUILD WITH (FILLFACTOR = 80);
		FETCH NEXT FROM TableCursor INTO @TableName,@IndexName;
	
	END

	CLOSE TableCursor;
	DEALLOCATE TableCursor;
 

	DECLARE @TableName varchar(255);
	DECLARE @IndexName varchar(255);
	set @TableName = 'table1';
	set @IndexName = 'IX_table1';
	select @TableName, @IndexName
	select  * from @TableName;
	ALTER INDEX @IndexName ON @TableName REBUILD WITH (FILLFACTOR = 80, ONLINE = ON);












???????????????????????????????????????????????????????????????????????????????????????????????????????
USE AdventureWorks
GO

CREATE PROCEDURE dbo.b_reindex @database SYSNAME, @fragpercent INT
AS

DECLARE	
	@cmd NVARCHAR(max),
	@table SYSNAME,
	@schema SYSNAME

DECLARE curtable CURSOR FOR
	SELECT DISTINCT OBJECT_SCHEMA_NAME(object_id, database_id) SchemaName, OBJECT_NAME(object_id, database_id) TableName
	FROM sys.dm_db_index_physical_stats(DB_ID(@database), NULL, NULL, NULL, 'SAMPLED')
	WHERE avg_fragmentation_in_percent >= @fragpercent
FOR READ ONLY
OPEN curtable 
FETCH curtable INTO @schema, @table

WHILE @@FETCH_STATUS = 0
BEGIN
	SET @cmd = 'ALTER INDEX ALL ON ' + @database + '.' + @schema + '.' + @table + ' REBUILD WITH (ONLINE = ON)'
	PRINT @cmd
	BEGIN TRY
		EXEC sp_executesql @cmd
	END TRY
	BEGIN CATCH
		BEGIN
			SET @cmd = 'ALTER INDEX ALL ON ' + @database + '.' + @schema + '.' + @table + ' REBUILD WITH (ONLINE = OFF)'
			PRINT @cmd
			EXEC sp_executesql @cmd
		END
	END CATCH
	FETCH curtable INTO @schema, @table
END

CLOSE curtable
DEALLOCATE curtable
GO
