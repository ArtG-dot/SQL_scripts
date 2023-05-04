/*
Temp objects:
Local temp table (#) -	локальная временная таблица (scope level - session), можно явно создавать индексы и статистику, есть св-во identity, по сути ничем не отличается от обычной таблицы в БД 
Global temp table (##) - глобальная временная таблица, можно явно создавать индексы и статистику
Table variable (@) - табличная переменная (scope level - batch), можно неявно создавать индексы через ограничения, 
	можно создать переменную типа таблицы в памяти (Memory-optimized table type)
In-mempry table (SCHEMA_ONLY) - для временных объектов можно исп. In-mempry table, не сохраняя анные на диске (SCHEMA_ONLY),
	в этом случае работа с данными ведется в памяти без использования tempdb, это хорошая альтернатива для ##table
	https://docs.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/faster-temp-table-and-table-variable-by-using-memory-optimization

Возможности						#temp			##temp			@temp
Scope level						session			server			batch
св-во identity					+				+				+
создание индексов				+				+				+/- (можно создавать через constraints, но явно имена давать нельзя)
сжатие							+				+				-
статистика						+				+				- (оптимизатор считает что всегда 1 строка, но это можно убрать хинтом recompile)

*/

-------------------------------
/*локальная временная таблица*/
-------------------------------
--создание
--вариант 1. через SELECT INTO
	drop table if exists #temp;
	select * into #temp from ttt;
 
--вариант 2. через CREATE TABLE
--создаем
	drop table if exists #temp;
	create table #temp (id int identity, val_int int, val_char char(200));
--заполняем
	; with N1(C) as (select 0 union all select 0) -- 2 rows
	,N2(C) as (select 0 from N1 as T1 CROSS JOIN N1 as T2) -- 4 rows
	,N3(C) as (select 0 from N2 as T1 CROSS JOIN N2 as T2) -- 16 rows
	,N4(C) as (select 0 from N3 as T1 CROSS JOIN N3 as T2) -- 256 rows
	,N5(C) as (select 0 from N4 as T1 CROSS JOIN N4 as T2) -- 65,536 rows
	,IDs(ID) as (select row_number() over (order by (select NULL)) from N5)
	insert into #temp (val_int, val_char) select id + 100000, 'some data' from IDs

select * from #temp;

--временные таблицы хранятся в tempdb
	select * from tempdb.sys.tables where name like '#temp%' 
	select * from tempdb.sys.indexes where object_id = (select object_id from tempdb.sys.tables where name like '#temp%');

--можно создать CI или NCI (явно либо через ограничения), они также будут храниться в tempdb
	alter table #temp add constraint PK_#temp PRIMARY KEY (ID);
	create unique index NCI_#temp_val on #temp (val_int);
	alter table #temp add constraint UQ_#temp unique (ID);
	select * from tempdb.sys.indexes where object_id = (select object_id from tempdb.sys.tables where name like '#temp%');

--можно создать статистику
	select * from tempdb.sys.stats where object_id = (select object_id from tempdb.sys.tables where name like '#temp%'); --0
	select * from #temp where id = 999;
	select * from tempdb.sys.stats where object_id = (select object_id from tempdb.sys.tables where name like '#temp%'); --1
	create statistics temp_stat on #temp(val_int) with fullscan;
	select * from #temp where val_int = 999;
	select * from tempdb.sys.stats where object_id = (select object_id from tempdb.sys.tables where name like '#temp%'); --2

--можно сжать временную таблицу
	select t.name, p.row_count, p.used_page_count, p.reserved_page_count from tempdb.sys.tables t join tempdb.sys.dm_db_partition_stats p on p.object_id = t.object_id and t.name like '#temp%';
	alter table #temp rebuild partition =  all with (data_compression = page);
	select t.name, p.row_count, p.used_page_count, p.reserved_page_count from tempdb.sys.tables t join tempdb.sys.dm_db_partition_stats p on p.object_id = t.object_id and t.name like '#temp%';



-------------------------------
/*глобальная временная таблица*/
-------------------------------
--создание (по сути аналогично #)
--вариант 1. через SELECT INTO
	drop table if exists ##temp;
	select * into ##tempw from ttt;
 
--вариант 2. через CREATE TABLE
--создаем
	drop table if exists ##temp;
	create table ##temp (id int identity, val_int int, val_char char(200));

	

------------------------
/*табличная переменная*/
------------------------
--объявление, заполнение и проверка (все в одном batch)
	declare @temp table (id int identity, val_int int, val_char char(200));
	; with N1(C) as (select 0 union all select 0) -- 2 rows
		,N2(C) as (select 0 from N1 as T1 CROSS JOIN N1 as T2) -- 4 rows
		,N3(C) as (select 0 from N2 as T1 CROSS JOIN N2 as T2) -- 16 rows
		,N4(C) as (select 0 from N3 as T1 CROSS JOIN N3 as T2) -- 256 rows
		,N5(C) as (select 0 from N4 as T1 CROSS JOIN N4 as T2) -- 65,536 rows
		,IDs(ID) as (select row_number() over (order by (select NULL)) from N5)
		insert into @temp (val_int, val_char) select id + 100000, 'some data' from IDs;
	select * from tempdb.sys.tables where create_date > DATEADD(MINUTE,-3,getdate());
	select * from @temp;

--создание индекса (только через создание ограничений при объевлении переменной)
	declare @temp table (id int identity primary key clustered, val_int int unique nonclustered, val_char char(200));
		--либо так declare @temp table (id int identity, val_int int, val_char char(200), primary key clustered (id), unique nonclustered (val_int));
	; with N1(C) as (select 0 union all select 0) -- 2 rows
		,N2(C) as (select 0 from N1 as T1 CROSS JOIN N1 as T2) -- 4 rows
		,N3(C) as (select 0 from N2 as T1 CROSS JOIN N2 as T2) -- 16 rows
		,N4(C) as (select 0 from N3 as T1 CROSS JOIN N3 as T2) -- 256 rows
		,N5(C) as (select 0 from N4 as T1 CROSS JOIN N4 as T2) -- 65,536 rows
		,IDs(ID) as (select row_number() over (order by (select NULL)) from N5)
		insert into @temp (val_int, val_char) select id + 100000, 'some data' from IDs;
	select * from tempdb.sys.tables where create_date > DATEADD(MINUTE,-3,getdate());
	select * from tempdb.sys.indexes i where i.object_id = (select object_id from tempdb.sys.tables where create_date > DATEADD(MINUTE,-3,getdate()))
	select * from @temp;

--объявление на основе уже существующего типа данных, заполнение и проверка (все в одном batch) 
	drop type if exists dbo.typeTableD;	
	CREATE TYPE dbo.typeTableD AS TABLE  --создание типа данных на основе таблицы (user-defined table type)
		(  	Column1  INT   NOT NULL ,  
			Column2  CHAR(10) );  
        
	DECLARE @tvTableD dbo.typeTableD;  
	INSERT INTO @tvTableD (Column1) values (1), (2);  
	SELECT * from @tvTableD;

	drop TYPE dbo.typeTableD;

--табличная переменная в памяти
--объявление на основе уже существующего типа данных, заполнение и проверка (все в одном batch) 
	drop type if exists dbo.typeTableD;
	CREATE TYPE dbo.typeTableD AS TABLE  --создание типа данных на основе таблицы (user-defined Memory-optimized table type)
		(  	Column1  INT NOT NULL index ix_temp unique nonclustered,  --необходимо что на in-memory table был хотя бы 1 индекс
			Column2  CHAR(10) )
		WITH (MEMORY_OPTIMIZED = ON); 
        
	DECLARE @tvTableD dbo.typeTableD;  
	INSERT INTO @tvTableD (Column1) values (1), (2);  
	SELECT * from @tvTableD;






-----------------------------------------------------------------------------------------------------------------------------------------------
/*различия в работе с транзакциями*/
--лок. врем. таблица
drop table if exists #temp;
create table #temp (id int identity, val varchar(50));
begin tran
	select * from #temp;
	insert into #temp(val) values ('a');
	insert into #temp(val) values ('b');
	insert into #temp(val) values ('c');
	select * from #temp;
rollback tran
select * from #temp; --транзакция откатилась, и данные из таблицы удалены

--табл. переменная
declare @temp table (id int identity, val varchar(50));
begin tran
	select * from @temp;
	insert into @temp(val) values ('a');
	insert into @temp(val) values ('b');
	insert into @temp(val) values ('c');
	select * from @temp;
rollback tran
select * from @temp; --транзакция откатилась, но данные из таблицы не удалены (т.е. все изменения связанные с переменной остались в силе)



/*различия в работе с опртимизатором*/
--лок. врем. таблица
	DBCC FREEPROCCACHE WITH NO_INFOMSGS; --чистим кэш
	drop table if exists #temp;
	create table #temp (id int identity, val_int int, val_char char(200)
		, constraint PK_#temp primary key clustered (id)
		, constraint UQ_#temp unique nonclustered (val_int));
	; with N1(C) as (select 0 union all select 0) -- 2 rows
	,N2(C) as (select 0 from N1 as T1 CROSS JOIN N1 as T2) -- 4 rows
	,N3(C) as (select 0 from N2 as T1 CROSS JOIN N2 as T2) -- 16 rows
	,N4(C) as (select 0 from N3 as T1 CROSS JOIN N3 as T2) -- 256 rows
	,N5(C) as (select 0 from N4 as T1 CROSS JOIN N4 as T2) -- 65,536 rows
	,IDs(ID) as (select row_number() over (order by (select NULL)) from N5)
	insert into #temp (val_int, val_char) select id + 100000, 'some data' from IDs

	select * from #temp where val_int = 165535; --esimated rows = 1, actual rows = 1, NCI seek + lookup		(OK)
	select * from #temp where val_int > 165535; --esimated rows = 1, actual rows = 1, NCI seek + lookup		(OK)
	select * from #temp where val_int > 160000; --esimated rows = 5500, actual rows = 5500, CI scan			(OK)
	select * from #temp							--esimated rows = 65500, actual rows = 65500, CI scan		(OK)


--табл. переменная
	DBCC FREEPROCCACHE WITH NO_INFOMSGS; --чистим кэш
	declare @temp table (id int identity, val_int int, val_char char(200)
	, primary key clustered (id)
	, unique nonclustered (val_int));
	; with N1(C) as (select 0 union all select 0) -- 2 rows
		,N2(C) as (select 0 from N1 as T1 CROSS JOIN N1 as T2) -- 4 rows
		,N3(C) as (select 0 from N2 as T1 CROSS JOIN N2 as T2) -- 16 rows
		,N4(C) as (select 0 from N3 as T1 CROSS JOIN N3 as T2) -- 256 rows
		,N5(C) as (select 0 from N4 as T1 CROSS JOIN N4 as T2) -- 65,536 rows
		,IDs(ID) as (select row_number() over (order by (select NULL)) from N5)
		insert into @temp (val_int, val_char) select id + 100000, 'some data' from IDs;

	select * from @temp where val_int = 165535; --esimated rows = 1, actual rows = 1, NCI seek + lookup		(OK)
	select * from @temp where val_int > 165535; --esimated rows = 1, actual rows = 1, CI scan				(not OK)
	select * from @temp where val_int > 160000; --esimated rows = 1, actual rows = 5500, CI scan			(OK)
	select * from @temp							--esimated rows = 1, actual rows = 65500, CI scan			(OK)

--табл. переменная (с хинтом RECOMPILE, предполагает что esimated rows = 30% от всего кол-ва строк)
	DBCC FREEPROCCACHE WITH NO_INFOMSGS; --чистим кэш
	declare @temp table (id int identity, val_int int, val_char char(200)
	, primary key clustered (id)
	, unique nonclustered (val_int));
	; with N1(C) as (select 0 union all select 0) -- 2 rows
		,N2(C) as (select 0 from N1 as T1 CROSS JOIN N1 as T2) -- 4 rows
		,N3(C) as (select 0 from N2 as T1 CROSS JOIN N2 as T2) -- 16 rows
		,N4(C) as (select 0 from N3 as T1 CROSS JOIN N3 as T2) -- 256 rows
		,N5(C) as (select 0 from N4 as T1 CROSS JOIN N4 as T2) -- 65,536 rows
		,IDs(ID) as (select row_number() over (order by (select NULL)) from N5)
		insert into @temp (val_int, val_char) select id + 100000, 'some data' from IDs;

	select * from @temp where val_int = 165535 option (recompile); --esimated rows = 1, actual rows = 1, NCI seek + lookup		(OK)
	select * from @temp where val_int > 165535 option (recompile); --esimated rows = 19660, actual rows = 1, CI scan			(not OK)
	select * from @temp where val_int > 160000 option (recompile); --esimated rows = 19660, actual rows = 5500, CI scan			(OK)
	select * from @temp	option (recompile);							--esimated rows = 65500, actual rows = 65500, CI scan		(OK)
