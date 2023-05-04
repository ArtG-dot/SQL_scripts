--------------------------------------------------------------------------------------------
--------------------------------------------Info--------------------------------------------
--------------------------------------------------------------------------------------------
DBCC TRACEON (3604)
DBCC DBINFO

/*основные параметры текущей БД*/
select * from master.sys.databases where database_id = db_id()

select 
	DB_NAME() 'current DB name' --DB_NAME(5) возвращает имя БД с id = 5
	, DB_ID() 'current DB id' --DB_ID('master') возвращает id конкретной БД
	, ORIGINAL_DB_NAME() 'original DB name' --к какой БД был первый коннект
	, DATABASEPROPERTYEX(DB_NAME(), 'InstanceName')
	, DATABASEPROPERTYEX(DB_NAME(), 'Collation')
	, DATABASEPROPERTYEX(DB_NAME(), 'Version')
	, DATABASEPROPERTYEX(DB_NAME(), 'UserAccess')

/*размер БД: 
общий текущий размер, владелец БД, ID БД
файлы БД (логич. имя), расположение (физич. имя), файл. группа, размер файла, макс. размер, автоувелич. файла
db_size = data_file (.mdf, .ndf) + log_file (.ldf) (сумма всех файлов БД)*/
exec sp_helpdb; --размеры всех БД 
exec sp_helpdb 's'; --по отдельной БД (размер + все файлы БД)
	
exec sp_helpfile --информация о файлах, относящихся к текущей базе данных
	exec sp_helpfile 'TEST_Data_1' --информация о конкретном файле
exec sp_helpfilegroup -- информация обо всех файловых группах в текущей базе данных
	exec sp_helpfilegroup 'FG2' --информация о конкретной файловой группе


/*размер БД:
имя БД, общий текущий размер, размер нераспределенного пространства
reserved = data + index_size + unused*/
/* database_size = data_file (.mdf, .ndf) + log_file (.ldf) (сумма всех файлов БД)
database_size = reserved + unallocated space + log_file (весь объем БД)
data_file (.mdf, .ndf) = reserved(зарезервированное пространство) + unallocated space(незарезервированное/нераспределенное пространство)
unallocated space = data_file (.mdf, .ndf) - reserved (место в БД, не зарезервировванное для объектов БД)
unallocated space = space available (свободное место в БД)

reserved = data + index_size + unused = total pages size (место, зарезервированное и используемое под объекты БД)
XML-Index and FT-Index internal tables are not considered "data", but is part of "index_size" */ 
exec sp_spaceused
--exec sp_spaceused 'ap_reqwest'; --размер объекта в БД
select * from sys.dm_db_file_space_usage

/*размер БД
все размеры файлов БД (size, growth) - это кол-во страниц (по 8 КБ), т.е. реальный размер файла = size*8(KB)*/
select * from sys.database_files
select * from sys.master_files where database_id = db_id()
select * from sys.sysfiles; 
exec sp_helpfile

/*список всех файловых групп*/
select * from sys.filegroups;
select * from sys.sysfilegroups;

select 
	DB_NAME() 'current DB name' --DB_NAME(5) возвращает имя БД с id = 5
	, DB_ID() 'current DB id' --DB_ID('master') возвращает id конкретной БД
	, sum(convert(bigint,size))*8/1024 'db size (MB)' --размер текущей БД
	, sum(convert(bigint,case when status & 64 = 0 then size else 0 end))*8/1024 'data files size (MB)' -- & (побитовое И)
	, sum(convert(bigint,case when status & 64 <> 0 then size else 0 end))*8/1024 'log files size (MB)'
  from dbo.sysfiles


/*размер БД + размер свободного пространства в БД для возможного SHRINK DB*/
 select 
db_name() [database],
	(select sum(size)*8/1024 from sys.sysfiles where groupid = 1) [data files size (MB)], 
	sum(a.total_pages)*8/1024 [reserved (MB)], 
	sum(  
	CASE  
	-- XML-Index and FT-Index and semantic index internal tables are not considered "data", but is part of "index_size"  
		When it.internal_type IN (202,204,207,211,212,213,214,215,216,221,222,236) Then 0  
		When a.type <> 1 and p.index_id < 2 Then a.used_pages  
		When p.index_id < 2 Then a.data_pages  
		Else 0  
		END  
	) *8/1024 [data (MB)],  
	sum(a.used_pages)*8/1024 [data + index (MB)],
	(sum(a.used_pages)-sum(  
	CASE  
	-- XML-Index and FT-Index and semantic index internal tables are not considered "data", but is part of "index_size"  
		When it.internal_type IN (202,204,207,211,212,213,214,215,216,221,222,236) Then 0  
		When a.type <> 1 and p.index_id < 2 Then a.used_pages --LOB, CLR данные и данные, превышающие размер страницы 
		When p.index_id < 2 Then a.data_pages --куча(0) или кластеризованный индекс(1)
		Else 0  
		END  
	)) *8/1024  [index (MB)],
	sum(a.total_pages)*8/1024 - sum(a.used_pages)*8/1024 [unused (MB)] 
from sys.partitions p join sys.allocation_units a on p.partition_id = a.container_id  
left join sys.internal_tables it on p.object_id = it.object_id;

db cc updateusage (0);
/*Обновляет информацию о представления системного каталога.
На больших БД может занимать значительное время.*/


--------------------------------------------------------------------------------------------------------
-------------------------------------------Размер объекта в БД-------------------------------------------
--------------------------------------------------------------------------------------------------------

	select * from sys.internal_tables;
	/*объекты какой-либо внутренней таблицы*/

	select * from sys.partitions; 
	/*одна строка для каждой секции(партиции) всех таблиц и большинства типов индексов (кроме полнотекстовых,
	пространственных и XML-индексов).
	Каждая таблица и индекс содержат минимум 1 секцию, даже если они явно не секционированы*/

	select * from sys.allocation_units; 
	/*одна строка для каждой единицы распределения в БД*/

declare @obj_name varchar(50);
set @obj_name = 'reqwest'

exec sp_spaceused @obj_name;
/*размер объекта БД*/

select * from sys.partitions p 
left join sys.allocation_units a on p.partition_id = a.container_id
where p.object_id = OBJECT_ID(@obj_name);
/*все секции для оъектаа БД*/

select * from sys.objects where name = @obj_name

--аналог exec sp_spaceused, размер в МБ, погрешность из-за целочисленных значений, вместо дробных
select
@obj_name 'object name' 
, SUM(a.total_pages)*8/1024 'Total (KB)'
, SUM(a.used_pages)*8/1024 'Used (KB)'
, SUM(CASE 
	WHEN a.type <> 1 AND p.index_id < 2 THEN a.used_pages
	WHEN p.index_id < 2 THEN a.data_pages
	ELSE 0
	END)*8/1024 'Data (KB)'
, (SUM(a.used_pages) - SUM(CASE 
	WHEN a.type <> 1 AND p.index_id < 2 THEN a.used_pages
	WHEN p.index_id < 2 THEN a.data_pages --куча(0) или кластеризованный индекс(1)
	ELSE 0 
	END))*8/1024 'Index (KB)'
, (SUM(a.total_pages) - SUM(a.used_pages))*8/1024 'Unused (KB)'
from sys.partitions p 
	join sys.allocation_units a	
		on p.partition_id = a.container_id  
	left join sys.internal_tables it 
		on p.object_id = it.object_id
where p.object_id = OBJECT_ID(@obj_name) --размер отдельной таблицы













