-------------------------------------
/*In-Memory Temporary Tables (2016)*/
-------------------------------------
/*таблица хранится в отдельной файловой группе MEMORY_OPTIMIZED
таблица не поддерживает кластерный индекс (?)
таблица должна содержать хотя бы один некластерный индекс
существует 3(?) типа индексов для In-Memory Temporary Tables: nonclustered index, columnstore clustered index, hash-index
	nonclustered index исп для range-поиска
	nonclustered hash index исп для point-поиска, для него нужно определить кол-во buckets (обычно двойное кол-во от уникальных значений для ключа), не поддерживает NULL
таблица не поддерживает автоматичекое обновление статистики

Also starting with SQL Server 2016, we are able to create a Clustered Columnstore index on the top of a Memory-Optimized tables

Memory-optimized tables use the optimistic transaction isolation level (row versioning built in, instead of Disk-based tables which use tempdb)
включенная настройка БД MEMORY_OPTIMIZED_ELEVATE_TO_SNAPSHOT повышает уровень изолированности транзакций с READ COMMITTED или READ UNCOMMITTED до SNAPSHOT 

Memory-optimized tables can be accessed most efficiently from natively compiled stored procedures
*/


/*создание In-Memory Temporary Tables*/
--создаем MEMORY_OPTIMIZED_FILEGROUP
	ALTER DATABASE db1 ADD FILEGROUP FgMemOptim CONTAINS MEMORY_OPTIMIZED_DATA;  
	go
--добавляем файл
	ALTER DATABASE db1 ADD FILE (  
			NAME = N'TESt_FgMemOptim',  
			FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\TESt_FgMemOptim'  
		)  TO FILEGROUP FgMemOptim;  
	go  
				--не обязательно (зависит от необходимости)
				--ALTER DATABASE TEST SET MEMORY_OPTIMIZED_ELEVATE_TO_SNAPSHOT=ON  
--создание таблицы
	drop table if exists memTbl;
	CREATE TABLE memTbl
	(  
	id int identity INDEX ix1 unique nonclustered 
	, val varchar(50) 
	) WITH (MEMORY_OPTIMIZED = ON
		, DURABILITY = SCHEMA_ONLY); --{SCHEMA_ONLY | SCHEMA_AND_DATA}
--вручную обновляем статистику
	update statistics dbo.memTbl with fullscan, norecompute



/*In-Memory Temporary Tables и columnstore indexes*/
--на In-Memory Temporary Table можно создать columnstore index
--в этом случае нельзя изменять структуру таблицы (ALTER TABLE)
	drop table if exists memTbl;
	CREATE TABLE memTbl
	(  
	id int identity constraint PK_memTbl primary key nonclustered --для CCI нужно создать PK (clustered index не поддерживается, поэтому создаем nonclustered PK)
	, val varchar(50) 
	, INDEX CCI_memTbl CLUSTERED COLUMNSTORE
	) WITH (MEMORY_OPTIMIZED = ON
		, DURABILITY = SCHEMA_AND_DATA); --для CCI нужно исп настройку SCHEMA_AND_DATA





-----------------------------------------------------------------------------------------------------------------
set statistics time on

/*сравниваем скорость работы таблиц: вставка 10 млн записей
сравниваем только скорость вставки данных, т.е. операцию INSERT
*/
--таблица на диске + вспомогательная временная таблица
	drop table if exists dscTbl, #tab;
	create table #tab (num int);
	insert into #tab values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

	create table dscTbl (id int identity, val varchar(20));

	insert into dscTbl(val)
		select 
		'aaa' val
		from #tab t1
		cross join #tab t2
		cross join #tab t3
		cross join #tab t4
		cross join #tab t5
		cross join #tab t6
		cross join #tab t7;

	select count(*) from dscTbl with (nolock)
	drop table if exists dscTbl, #tab;

 SQL Server Execution Times:
   CPU time = 55486 ms,  elapsed time = 150981 ms.

------------------------------------------------------------------------------------------------------------------------------------
--таблица на диске + вспомогательная таблица на диске
	drop table if exists dscTbl, temp;
	create table temp (num int);
	insert into temp values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

	create table dscTbl (id int identity, val varchar(20));

	insert into dscTbl(val)
		select 
		'aaa' val
		from temp t1
		cross join temp t2
		cross join temp t3
		cross join temp t4
		cross join temp t5
		cross join temp t6
		cross join temp t7;

	select count(*) from dscTbl with (nolock)
	drop table if exists dscTbl, temp;

 SQL Server Execution Times:
   CPU time = 62218 ms,  elapsed time = 149803 ms.

 ------------------------------------------------------------------------------------------------------------------------------------
 --таблица в памяти + вспомогательная временная таблица
	drop table if exists memTbl, #tab;
	create table #tab (num int);
	insert into #tab values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

	CREATE TABLE memTbl
	(  
	id int identity INDEX ix1 NONCLUSTERED 
	, val varchar(20) 
	) WITH (MEMORY_OPTIMIZED = ON
		, DURABILITY = SCHEMA_ONLY);

	insert into memTbl(val)
		select 
		'aaa' val
		from #tab t1
		cross join #tab t2
		cross join #tab t3
		cross join #tab t4
		cross join #tab t5
		cross join #tab t6
		cross join #tab t7;

	select count(*) from memTbl with (nolock)
	drop table if exists memTbl, #tab;

 SQL Server Execution Times:
   CPU time = 36609 ms,  elapsed time = 36640 ms.

------------------------------------------------------------------------------------------------------------------------------------
 --таблица в памяти + вспомогательная таблица в памяти
	drop table if exists memTbl, temp;
	CREATE TABLE temp
	(  
	id int not null INDEX ix1 NONCLUSTERED hash WITH (BUCKET_COUNT=20)
	) WITH (MEMORY_OPTIMIZED = ON
		, DURABILITY = SCHEMA_ONLY);
	insert into temp(id) values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

	CREATE TABLE memTbl
	(  
	id int identity INDEX ix1 NONCLUSTERED 
	, val varchar(20) 
	) WITH (MEMORY_OPTIMIZED = ON
		, DURABILITY = SCHEMA_ONLY);

	insert into memTbl(val)
		select 
		'aaa' val
		from temp t1
		cross join temp t2
		cross join temp t3
		cross join temp t4
		cross join temp t5
		cross join temp t6
		cross join temp t7;

	select count(*) from memTbl with (nolock)
	drop table if exists memTbl, temp;

 SQL Server Execution Times:
   CPU time = 34094 ms,  elapsed time = 34148 ms.

------------------------------------------------------------------------------------------------------------------------------------
 --таблица в памяти + вспомогательная таблица в памяти через ХП native_compilation
	drop proc if exists natSP;
	drop table if exists memTbl, temp;

	CREATE TABLE temp
	(  
	id int not null INDEX ix1 NONCLUSTERED hash WITH (BUCKET_COUNT=20)
	) WITH (MEMORY_OPTIMIZED = ON
		, DURABILITY = SCHEMA_ONLY);
	insert into temp(id) values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

	CREATE TABLE memTbl
	(  
	id int identity INDEX ix1 NONCLUSTERED 
	, val varchar(20) 
	) WITH (MEMORY_OPTIMIZED = ON
		, DURABILITY = SCHEMA_ONLY);

	create proc dbo.natSP
	with native_compilation, schemabinding, execute as owner
	as begin atomic
		with (transaction isolation level = snapshot, language = N'us_english')

		insert into dbo.memTbl(val)
			select 
			'aaa' val
			from dbo.temp t1
			cross join dbo.temp t2
			cross join dbo.temp t3
			cross join dbo.temp t4
			cross join dbo.temp t5
			cross join dbo.temp t6
			cross join dbo.temp t7;
	end

	exec dbo.natSP;

	select count(*) from memTbl with (nolock)
	drop proc if exists natSP;
	drop table if exists memTbl, temp;

 SQL Server Execution Times:
   CPU time = 19765 ms,  elapsed time = 19784 ms.

------------------------------------------------------------------------------------------------------------------------------------
 --таблица в памяти + цикл WHILE через ХП native_compilation
	drop proc if exists natSP;
	drop table if exists memTbl;

	CREATE TABLE memTbl
	(  
	id int identity INDEX ix1 NONCLUSTERED 
	, val varchar(20) 
	) WITH (MEMORY_OPTIMIZED = ON
		, DURABILITY = SCHEMA_ONLY);

	create proc dbo.natSP
	with native_compilation, schemabinding, execute as owner
	as begin atomic
		with (transaction isolation level = snapshot, language = N'us_english')

		declare @i int  = 0;

		while @i < 10000000
		begin
			insert into dbo.memTbl(val) values (@i);
			set @i = @i + 1
		end
	end

	exec dbo.natSP;

	select count(*) from memTbl with (nolock)
	drop proc if exists natSP;
	drop table if exists memTbl, temp;

 SQL Server Execution Times:
   CPU time = 24969 ms,  elapsed time = 25202 ms.

