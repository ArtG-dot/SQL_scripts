--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------
/*информация о способе хранения объектов БД, которые содержат данные (таблицы, индексы)*/
select * from sys.data_spaces				--строка для каждого пространства данных, м.б. файловая группа (обычная, FILESTREAM, Memory-optimized) или схема секционирования

/*1. файловые группы и файлы*/
select * from sys.filegroups
select * from sys.database_files

/*2. партиционирование*/
select * from sys.partition_functions		--ф-ции сексионирования
select * from sys.partition_parameters		--параметры ф-ций секционирования (тип данных, collation)
select * from sys.partition_range_values	--все граничные (пороговые) значения диапазона ф-ции секционирования (тип R - range)
select * from sys.partition_schemes			--схемы секционирования
select * from sys.destination_data_spaces	--строка для каждой цели пространства данных согласно схеме секционирования (область <-> пространство данных, файловая группа)

select * from sys.partitions				--секции
select * from sys.dm_db_partition_stats		--статистика по секциям (allocation unit, страниц, строк и тп) 
select * from sys.system_internals_partitions





/*вместо партиционированной таблицы можно создать несколько отдельных таблиц (с одинаковой структурой) и задать партиционированное представление (partitioned view):
create table t1 ...
create table t2 ...
create table t3 ...

create view t as
	select col1, col2,... from t1
	union all
	select col1, col2,... from t2
	union all
	select col1, col2,... from t3

	*/






----------------------------------------------------------------------------------------------------------------------------------------------
/*группы секционирования с границами*/
select pf.name prt_fn_mn
, ps.name prt_schm_mn
--, pf.fanout						--число секций
, dd.destination_id
, lag(rv.value,1,'') over (order by dd.destination_id) min_value
, isnull(rv.value,'') max_value
--, pf.boundary_value_on_right --какому индервалу принадлежит граница
, isnull(cast(lag(rv.value,1) over (order by dd.destination_id) as varchar(50)) + iif(pf.boundary_value_on_right = 1, ' <= ',' < '),'') 
	+ ' x ' + isnull(iif(pf.boundary_value_on_right = 1, ' < ', ' <= ') + cast(rv.value as varchar(50)), '') borders
, ds.name fg_nm
from sys.partition_functions pf
left join sys.partition_schemes ps
	on ps.function_id = pf.function_id
left join sys.destination_data_spaces dd
	on dd.partition_scheme_id = ps.data_space_id
left join sys.data_spaces ds
	on ds.data_space_id = dd.data_space_id
full join sys.partition_range_values rv
	on rv.function_id = pf.function_id
	and rv.boundary_id = dd.destination_id
where pf.name = 'prt_fun'
order by dd.destination_id



/*заполнение партиций для объекта*/
select OBJECT_NAME(p.object_id) tbl_nm
, p.index_id
, p.partition_number
, p.rows
, p.data_compression_desc
, ps.used_page_count
, case when ps.used_page_count*8/1024/1024 = 0 then 'less then 1' else cast(ps.used_page_count*8/1024/1024 as varchar(10)) end data_GB --данные
, ps.reserved_page_count
, case when ps.reserved_page_count*8/1024/1024 = 0 then 'less then 1' else cast(ps.reserved_page_count*8/1024/1024 as varchar(10)) end reserved_GB
, f.name
--, ps.in_row_data_page_count --страницы с данными
--, ps.in_row_used_page_count --страницы с данными + страницы управления данными (IAM, промежут. страницы индекса)
--, ps.in_row_reserved_page_count --общее число зарезервированных страниц для харанения и кправления данными
--, ps.row_overflow_used_page_count
--, ps.row_overflow_reserved_page_count
--, ps.lob_used_page_count
--, ps.lob_reserved_page_count
from sys.partitions p
join sys.dm_db_partition_stats ps
	on p.partition_id = ps.partition_id
left join sys.allocation_units a
	on a.container_id = case
							when a.type in (1,3) then p.hobt_id
							when a.type = 2 then p.partition_id
						end
left join sys.filegroups f
	on f.data_space_id = a.data_space_id
where p.object_id = OBJECT_ID('ttt')
order by p.partition_number


--------------------------------------------------------------------------------------------
-----------------------------------------Maintaince-----------------------------------------
--------------------------------------------------------------------------------------------
--1. добавление новой партиции для таблицы
	--1.1. добавляем новую файловую группу 
	ALTER DATABASE TEST 
		ADD FILEGROUP FG_5;

				ALTER DATABASE TEST 
					REMOVE FILEGROUP FG_5;

	--1.2. добавляем новый файл данных в эту файловую группу (не проверял)
	ALTER DATABASE Ccard ADD FILE (
			NAME = 'Fg_2019' --логич. имя
			, FILENAME = 'U:\data.sql\Fg_2019.ndf'
			, SIZE = 10000 MB
			, FILEGROWTH = 100 MB
		) TO FILEGROUP FG_2019;
	
	--1.3. помечаем файловую группу с помощью схемы секционирования для сохранения новой секции
	ALTER PARTITION SCHEME TheDateEndPScheme NEXT USED FG_2019

	--1.4. добавляем одну секцию к функции секционирования
	ALTER PARTITION FUNCTION ThedateEndPFN () 
		SPLIT RANGE (N'2020-01-01 00:00:00.000')






	drop PARTITION FUNCTION prt_fun

	drop pARTITION SCHEME prt_shm_r


/*создание функции секционирования (как разделять данные)*/
CREATE PARTITION FUNCTION prt_fun(INT)
AS RANGE RIGHT FOR VALUES --RIGHT/LEFT - отпределяют, какому интервалу принаблежит пороговое значение 
(100, 200, 300)
go
			--пример для datetime
			CREATE PARTITION FUNCTION partfunc (datetime) AS
			RANGE RIGHT FOR VALUES ('1/1/2005', '2/1/2005', '3/1/2005'
						, '4/1/2005', '5/1/2005', '6/1/2005'
						, '7/1/2005', '8/1/2005', '9/1/2005'
						, '10/1/2005', '11/1/2005', '12/1/2005')

--какому интервалу принадлежит пороговое значение можно проверить:
SELECT
 $PARTITION.prt_fun (99)	--1
, $PARTITION.prt_fun (100)	--2
, $PARTITION.prt_fun (101); --2


			CREATE PARTITION FUNCTION myRangePF1 (int)  AS RANGE LEFT FOR VALUES (1, 100, 1000);  -- пороговое значение принаблежит левому интервалу
			--Partition		1				2								3								4
			--Values		col1 <= 1		col1 > 1 AND col1 <= 100		col1 > 100 AND col1 <=1000		col1 > 1000

			CREATE PARTITION FUNCTION myRangePF2 (int)  AS RANGE RIGHT FOR VALUES (1, 100, 1000);  -- пороговое значение принаблежит правому интервалу
			--Partition		1				2								3								4
			--Values		col1 < 1		col1 >= 1 AND col1 < 100		col1 >= 100 AND col1 < 1000		col1 >= 1000

/*создание схемы секционирования (как/где хранить данные)*/
CREATE PARTITION SCHEME prt_shm_l
AS PARTITION prt_fun  --имя функции секционирования
TO (FG1, FG2, FG1, FG2)
go

			CREATE PARTITION SCHEME psSales
			AS PARTITION pfSales 
			ALL TO ([Primary]); --все партиции в одну файловую группу


			create table ttt (id int, val varchar(50)) on prt_shm(id)
			truncate tABLE TTT

			; with N1(C) as (select cast(rand(checksum(newid()))*400 as int) union all select cast(rand(checksum(newid()))*400 as int)) -- 2 rows
			,N2(C) as (select  cast(rand(checksum(newid()))*400 as int) from N1 as T1 CROSS JOIN N1 as T2) -- 4 rows
			,N3(C) as (select  cast(rand(checksum(newid()))*400 as int) from N2 as T1 CROSS JOIN N2 as T2) -- 16 rows
			,N4(C) as (select  cast(rand(checksum(newid()))*400 as int) from N3 as T1 CROSS JOIN N3 as T2) -- 256 rows
			,N5(C) as (select  cast(rand(checksum(newid()))*400 as int) from N4 as T1 CROSS JOIN N4 as T2) -- 65,536 rows
			insert into ttt(id,val)
				select C, 'AAAAA'
				from N5


			select * from ttt

			--выбрать данные только из определенной партиции:
			select * from ttt a
			where $partition.prt_fun(a.id) = 2

			--кол-во строк в каждой партиции:
			select $partition.prt_fun(id) prt_nmb, count(*) row_cnt
			from ttt
			group by $partition.prt_fun(id)
			order by prt_nmb



/*создание индекса на основе схемы секционирования*/
CREATE UNIQUE CLUSTERED INDEX IDX_Orders_OrderDate_Id
ON dbo.Orders(OrderDate,ID)
ON prt_shm(OrderDate) --вместо файловой группы указываем схему секционирования
go
/*лучше создавать "выровненный" индекс, т.е. созданный с таблице на одной схеме*/
CREATE UNIQUE INDEX IDX_Data_DateModified_Id_OrderDate
ON dbo.Orders(DateModified, ID, OrderDate)
ON prt_shm(OrderDate)
go



/*можно использовать оператор SWITCH для управлениями секциями
фзического перемещения данных не происходит, изменяются только метаданные
сама таблица (структура) сохраняется, но данные перемещаются
*/
--1. из Non-Partitioned Table в Non-Partitioned Table: целевая таблица дб пустая с аналогичной структурой (тип полей, наличие CI)
--1.1. создание необходимых объектов
	drop table if exists t1, t2;
	--таблицы дб в одной файловой группе, (не)иметь CI
	create table t1 (id int not null identity, val char(10)) on fg1;
	create table t2 (id int not null, val char(10)) on fg1;

	with N1(C) as (select 'aaaaaaaaaa' union all select 'aaaaaaaaaa') -- 2 rows
	,N2(C) as (select 'aaaaaaaaaa' from N1 as T1 CROSS JOIN N1 as T2) -- 4 rows
	,N3(C) as (select 'aaaaaaaaaa' from N2 as T1 CROSS JOIN N2 as T2) -- 16 rows
	,N4(C) as (select 'aaaaaaaaaa' from N3 as T1 CROSS JOIN N3 as T2) -- 256 rows
	,N5(C) as (select 'aaaaaaaaaa' from N4 as T1 CROSS JOIN N4 as T2) -- 65,536 rows
	insert into t1(val)
		select C
		from N5

	select count(*) t1 from t1;
	select count(*) t2 from t2;

--1.2. перевод таблицы в другую
alter table t1 switch to t2;

	select count(*) t1 from t1;
	select count(*) t2 from t2;

--1.3. перевод таблицы в другую файловую группу
	--1.3.1. через создание/пересоздание кластерного индекса
	create clustered index CI_test on t1(id) on fg3; --если таблица в виде кучи, то просто создаем CI с указанием новой файловой группы
	create clustered index CI_test on t1(id) WITH (DROP_EXISTING = ON) on fg1; --если CI уже существует, то указываем параметр DROP_EXISTING = ON

	--после этого можно удалить CI, если он не нужен
	drop index t1.CI_test;
	--или
	drop index CI_test on t2;

	--1.3.2. через удаление кластерного индекса
	drop index CI_test on t1 WITH (MOVE TO fg1)

	--1.3.3. через удаление ограничения PK
	ALTER TABLE UserLog DROP CONSTRAINT PK__UserLog__7F8B815172CE9EAE WITH (MOVE TO fg2)

	--1.3.4 создание копии таблицы в другой файловой группе
	select * into ...
	create clustered index ... on fg3
	drop index ...

	--1.3.5 создание копии таблицы в другой файловой группе (2016 SP2 and later)
	SELECT * INTO UserLogHistory1 ON FG3 FROM UserLog

--1.4. перевод таблицы в другую (ERROR - разные файловые группы)
alter table t2 switch to t1;



--2. из Non-Partitioned Table в Partition: происходит перемещение из отдельной таблицы в пустую партицию
	drop table if exists pt;
	create table pt (id int, val varchar(50)) on fg3; -- создаем в той же файловой группе
	
	alter table pt WITH CHECK 
		add constraint CH_pt check (id >= 200 and id < 300 and id is not null) --таблица должна содержать ограничение CHECK по аналогии с партицией + NULL (!!!)
		
			select $partition.prt_fun(id) prt_nmb, count(*) row_cnt
			from ttt
			group by $partition.prt_fun(id)
			order by prt_nmb

			select count(*) pt from pt

			select * from ttt where $partition.prt_fun(id) = 3

alter table pt switch to ttt partition 3;

--3. из Partition в Non-Partitioned Table: происходит перемещение партиции в отдельную пустую таблицу
	drop table if exists pt;
	create table pt (id int, val varchar(50)) on fg3; -- создаем в той же файловой группе, условие CHECK не требуется, таблица дб пустая

alter table ttt switch partition 3 to pt;



--4. из Partition в Partition
ALTER TABLE SalesSource SWITCH PARTITION 1 TO SalesTarget PARTITION 1;




			SELECT o.[name] AS TableName, i.[name] AS IndexName, fg.[name] AS FileGroupName
			FROM sys.indexes i
			INNER JOIN sys.filegroups fg ON i.data_space_id = fg.data_space_id
			INNER JOIN sys.all_objects o ON i.[object_id] = o.[object_id]
			WHERE i.data_space_id = fg.data_space_id AND o.type = 'U'






CREATE TABLE SalesSource (
  SalesDate DATE,
  Quantity INT
) ON [PRIMARY];
-- Insert test data
INSERT INTO SalesSource(SalesDate, Quantity)
SELECT DATEADD(DAY,dates.n-1,'2012-01-01') AS SalesDate, qty.n AS Quantity
FROM GetNums(DATEDIFF(DD,'2012-01-01','2013-01-01')) dates
CROSS JOIN GetNums(1000) AS qty;









SELECT TOP 100 ID, OrderDate, DateModified, PlaceHolder
FROM    dbo.Orders 
WHERE   
	DateModified > @LastDateModified
	AND $partition.pfOrders(OrderDate) = 5
ORDER BY DateModified,Id

SELECT  @BoundaryCount = MAX(boundary_id) + 1
FROM    sys.partition_functions pf
        JOIN sys.partition_range_values prf 
			ON pf.function_id = prf.function_id
WHERE   pf.name = 'pfOrders'




;WITH  Boundaries(boundary_id)
AS 
(
	SELECT  1
	UNION ALL
	SELECT  boundary_id + 1
	FROM    Boundaries
	WHERE   boundary_id < @BoundaryCount
)
SELECT part.ID, part.OrderDate, part.DateModified,
	   $partition.pfOrders(part.OrderDate) AS [Partition Number]
FROM   Boundaries b
	   CROSS APPLY 
       (
		SELECT TOP 100 ID, OrderDate, DateModified
		FROM   dbo.Orders
		WHERE  DateModified > @LastDateModified
			   AND $Partition.pfOrders(OrderDate) = b.boundary_id
		ORDER BY DateModified, ID
		) part
go















