--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------
/*���������� � ������� �������� �������� ��, ������� �������� ������ (�������, �������)*/
select * from sys.data_spaces				--������ ��� ������� ������������ ������, �.�. �������� ������ (�������, FILESTREAM, Memory-optimized) ��� ����� ���������������

/*1. �������� ������ � �����*/
select * from sys.filegroups
select * from sys.database_files

/*2. �����������������*/
select * from sys.partition_functions		--�-��� ���������������
select * from sys.partition_parameters		--��������� �-��� ��������������� (��� ������, collation)
select * from sys.partition_range_values	--��� ��������� (���������) �������� ��������� �-��� ��������������� (��� R - range)
select * from sys.partition_schemes			--����� ���������������
select * from sys.destination_data_spaces	--������ ��� ������ ���� ������������ ������ �������� ����� ��������������� (������� <-> ������������ ������, �������� ������)

select * from sys.partitions				--������
select * from sys.dm_db_partition_stats		--���������� �� ������� (allocation unit, �������, ����� � ��) 
select * from sys.system_internals_partitions





/*������ ������������������ ������� ����� ������� ��������� ��������� ������ (� ���������� ����������) � ������ ������������������ ������������� (partitioned view):
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
/*������ ��������������� � ���������*/
select pf.name prt_fn_mn
, ps.name prt_schm_mn
--, pf.fanout						--����� ������
, dd.destination_id
, lag(rv.value,1,'') over (order by dd.destination_id) min_value
, isnull(rv.value,'') max_value
--, pf.boundary_value_on_right --������ ��������� ����������� �������
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



/*���������� �������� ��� �������*/
select OBJECT_NAME(p.object_id) tbl_nm
, p.index_id
, p.partition_number
, p.rows
, p.data_compression_desc
, ps.used_page_count
, case when ps.used_page_count*8/1024/1024 = 0 then 'less then 1' else cast(ps.used_page_count*8/1024/1024 as varchar(10)) end data_GB --������
, ps.reserved_page_count
, case when ps.reserved_page_count*8/1024/1024 = 0 then 'less then 1' else cast(ps.reserved_page_count*8/1024/1024 as varchar(10)) end reserved_GB
, f.name
--, ps.in_row_data_page_count --�������� � �������
--, ps.in_row_used_page_count --�������� � ������� + �������� ���������� ������� (IAM, ��������. �������� �������)
--, ps.in_row_reserved_page_count --����� ����� ����������������� ������� ��� ��������� � ���������� �������
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
--1. ���������� ����� �������� ��� �������
	--1.1. ��������� ����� �������� ������ 
	ALTER DATABASE TEST 
		ADD FILEGROUP FG_5;

				ALTER DATABASE TEST 
					REMOVE FILEGROUP FG_5;

	--1.2. ��������� ����� ���� ������ � ��� �������� ������ (�� ��������)
	ALTER DATABASE Ccard ADD FILE (
			NAME = 'Fg_2019' --�����. ���
			, FILENAME = 'U:\data.sql\Fg_2019.ndf'
			, SIZE = 10000 MB
			, FILEGROWTH = 100 MB
		) TO FILEGROUP FG_2019;
	
	--1.3. �������� �������� ������ � ������� ����� ��������������� ��� ���������� ����� ������
	ALTER PARTITION SCHEME TheDateEndPScheme NEXT USED FG_2019

	--1.4. ��������� ���� ������ � ������� ���������������
	ALTER PARTITION FUNCTION ThedateEndPFN () 
		SPLIT RANGE (N'2020-01-01 00:00:00.000')






	drop PARTITION FUNCTION prt_fun

	drop pARTITION SCHEME prt_shm_r


/*�������� ������� ��������������� (��� ��������� ������)*/
CREATE PARTITION FUNCTION prt_fun(INT)
AS RANGE RIGHT FOR VALUES --RIGHT/LEFT - �����������, ������ ��������� ����������� ��������� �������� 
(100, 200, 300)
go
			--������ ��� datetime
			CREATE PARTITION FUNCTION partfunc (datetime) AS
			RANGE RIGHT FOR VALUES ('1/1/2005', '2/1/2005', '3/1/2005'
						, '4/1/2005', '5/1/2005', '6/1/2005'
						, '7/1/2005', '8/1/2005', '9/1/2005'
						, '10/1/2005', '11/1/2005', '12/1/2005')

--������ ��������� ����������� ��������� �������� ����� ���������:
SELECT
 $PARTITION.prt_fun (99)	--1
, $PARTITION.prt_fun (100)	--2
, $PARTITION.prt_fun (101); --2


			CREATE PARTITION FUNCTION myRangePF1 (int)  AS RANGE LEFT FOR VALUES (1, 100, 1000);  -- ��������� �������� ����������� ������ ���������
			--Partition		1				2								3								4
			--Values		col1 <= 1		col1 > 1 AND col1 <= 100		col1 > 100 AND col1 <=1000		col1 > 1000

			CREATE PARTITION FUNCTION myRangePF2 (int)  AS RANGE RIGHT FOR VALUES (1, 100, 1000);  -- ��������� �������� ����������� ������� ���������
			--Partition		1				2								3								4
			--Values		col1 < 1		col1 >= 1 AND col1 < 100		col1 >= 100 AND col1 < 1000		col1 >= 1000

/*�������� ����� ��������������� (���/��� ������� ������)*/
CREATE PARTITION SCHEME prt_shm_l
AS PARTITION prt_fun  --��� ������� ���������������
TO (FG1, FG2, FG1, FG2)
go

			CREATE PARTITION SCHEME psSales
			AS PARTITION pfSales 
			ALL TO ([Primary]); --��� �������� � ���� �������� ������


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

			--������� ������ ������ �� ������������ ��������:
			select * from ttt a
			where $partition.prt_fun(a.id) = 2

			--���-�� ����� � ������ ��������:
			select $partition.prt_fun(id) prt_nmb, count(*) row_cnt
			from ttt
			group by $partition.prt_fun(id)
			order by prt_nmb



/*�������� ������� �� ������ ����� ���������������*/
CREATE UNIQUE CLUSTERED INDEX IDX_Orders_OrderDate_Id
ON dbo.Orders(OrderDate,ID)
ON prt_shm(OrderDate) --������ �������� ������ ��������� ����� ���������������
go
/*����� ��������� "�����������" ������, �.�. ��������� � ������� �� ����� �����*/
CREATE UNIQUE INDEX IDX_Data_DateModified_Id_OrderDate
ON dbo.Orders(DateModified, ID, OrderDate)
ON prt_shm(OrderDate)
go



/*����� ������������ �������� SWITCH ��� ������������ ��������
���������� ����������� ������ �� ����������, ���������� ������ ����������
���� ������� (���������) �����������, �� ������ ������������
*/
--1. �� Non-Partitioned Table � Non-Partitioned Table: ������� ������� �� ������ � ����������� ���������� (��� �����, ������� CI)
--1.1. �������� ����������� ��������
	drop table if exists t1, t2;
	--������� �� � ����� �������� ������, (��)����� CI
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

--1.2. ������� ������� � ������
alter table t1 switch to t2;

	select count(*) t1 from t1;
	select count(*) t2 from t2;

--1.3. ������� ������� � ������ �������� ������
	--1.3.1. ����� ��������/������������ ����������� �������
	create clustered index CI_test on t1(id) on fg3; --���� ������� � ���� ����, �� ������ ������� CI � ��������� ����� �������� ������
	create clustered index CI_test on t1(id) WITH (DROP_EXISTING = ON) on fg1; --���� CI ��� ����������, �� ��������� �������� DROP_EXISTING = ON

	--����� ����� ����� ������� CI, ���� �� �� �����
	drop index t1.CI_test;
	--���
	drop index CI_test on t2;

	--1.3.2. ����� �������� ����������� �������
	drop index CI_test on t1 WITH (MOVE TO fg1)

	--1.3.3. ����� �������� ����������� PK
	ALTER TABLE UserLog DROP CONSTRAINT PK__UserLog__7F8B815172CE9EAE WITH (MOVE TO fg2)

	--1.3.4 �������� ����� ������� � ������ �������� ������
	select * into ...
	create clustered index ... on fg3
	drop index ...

	--1.3.5 �������� ����� ������� � ������ �������� ������ (2016 SP2 and later)
	SELECT * INTO UserLogHistory1 ON FG3 FROM UserLog

--1.4. ������� ������� � ������ (ERROR - ������ �������� ������)
alter table t2 switch to t1;



--2. �� Non-Partitioned Table � Partition: ���������� ����������� �� ��������� ������� � ������ ��������
	drop table if exists pt;
	create table pt (id int, val varchar(50)) on fg3; -- ������� � ��� �� �������� ������
	
	alter table pt WITH CHECK 
		add constraint CH_pt check (id >= 200 and id < 300 and id is not null) --������� ������ ��������� ����������� CHECK �� �������� � ��������� + NULL (!!!)
		
			select $partition.prt_fun(id) prt_nmb, count(*) row_cnt
			from ttt
			group by $partition.prt_fun(id)
			order by prt_nmb

			select count(*) pt from pt

			select * from ttt where $partition.prt_fun(id) = 3

alter table pt switch to ttt partition 3;

--3. �� Partition � Non-Partitioned Table: ���������� ����������� �������� � ��������� ������ �������
	drop table if exists pt;
	create table pt (id int, val varchar(50)) on fg3; -- ������� � ��� �� �������� ������, ������� CHECK �� ���������, ������� �� ������

alter table ttt switch partition 3 to pt;



--4. �� Partition � Partition
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















