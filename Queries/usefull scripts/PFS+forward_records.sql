/*проверка количества строк на странице в зависимости от типа данных*/
drop table if exists  ttt;

 CREATE TABLE [dbo].ttt
(
    [id01] bit  null,
	[id02] bit  null,
	[id03] bit  null,
	[id04] bit  null,
    [id05] bit  null,
	[id06] bit  null,
	[id07] bit  null,
	[id08] bit  null,
	[id09] bit  null,

);

INSERT INTO [dbo].ttt VALUES (1,1,1,1,1,1,1,1,1);

while (select count(*) from  sys.dm_db_database_page_allocations(DB_ID(),object_id('ttt'), NULL, NULL, 'DETAILED') t where is_allocated = 1) = 2
	INSERT INTO [dbo].ttt VALUES (1,1,1,1,1,1,1,1,1);

select count(*) from ttt


/*не зависит от NULLable и от размера имен полей

		тип данных	1	4	8	9
		bit			700	700	700	642
1 byt	tinyint		700	592	453	405
2 byt	smallint	700	453	308	275
4 byt	int			592	308	188	168
8 byt	bigint		453	188	106	94
1 byt	char(1)		700	592	453	405
2 byt	nchar(1)	700	453	308	275
*/



------------------------------------------------------------------------------------------------------------------------------------
/*пример неоптимального использования свободного пространства в куче: PFS-страницы*/
drop table if exists  ttt;
 CREATE TABLE [dbo].ttt
(
	val varchar(8000)
);

INSERT INTO [dbo].ttt VALUES ('a'); --1 page
	SELECT sys.fn_PhysLocFormatter(t.%%physloc%%) RowID, *  FROM [dbo].ttt as t;
	select t.index_id, t.page_level, t.allocated_page_file_id FileID, t.allocated_page_page_id PageID, 
	t.is_iam_page, t.page_free_space_percent free_space, t.page_type_desc, t.is_page_compressed
	from sys.dm_db_database_page_allocations(DB_ID(),object_id('ttt'), NULL, NULL, 'DETAILED') t
	where is_allocated = 1 --страница размещена
	order by index_id, is_iam_page desc, is_allocated desc, page_level desc, allocated_page_page_id

INSERT INTO [dbo].ttt VALUES (REPLICATE('b', 4037)); --2 pages
	SELECT sys.fn_PhysLocFormatter(t.%%physloc%%) RowID, *  FROM [dbo].ttt as t;
	select t.index_id, t.page_level, t.allocated_page_file_id FileID, t.allocated_page_page_id PageID, 
	t.is_iam_page, t.page_free_space_percent free_space, t.page_type_desc, t.is_page_compressed
	from sys.dm_db_database_page_allocations(DB_ID(),object_id('ttt'), NULL, NULL, 'DETAILED') t
	where is_allocated = 1 --страница размещена
	order by index_id, is_iam_page desc, is_allocated desc, page_level desc, allocated_page_page_id

	
drop table if exists  ttt;
 CREATE TABLE [dbo].ttt
(
	val varchar(8000)
);

INSERT INTO [dbo].ttt VALUES (REPLICATE('b', 4037)); --1 page
	SELECT sys.fn_PhysLocFormatter(t.%%physloc%%) RowID, *  FROM [dbo].ttt as t;
	select t.index_id, t.page_level, t.allocated_page_file_id FileID, t.allocated_page_page_id PageID, 
	t.is_iam_page, t.page_free_space_percent free_space, t.page_type_desc, t.is_page_compressed
	from sys.dm_db_database_page_allocations(DB_ID(),object_id('ttt'), NULL, NULL, 'DETAILED') t
	where is_allocated = 1 --страница размещена
	order by index_id, is_iam_page desc, is_allocated desc, page_level desc, allocated_page_page_id

INSERT INTO [dbo].ttt VALUES ('a'); --1 page
	SELECT sys.fn_PhysLocFormatter(t.%%physloc%%) RowID, *  FROM [dbo].ttt as t;
	select t.index_id, t.page_level, t.allocated_page_file_id FileID, t.allocated_page_page_id PageID, 
	t.is_iam_page, t.page_free_space_percent free_space, t.page_type_desc, t.is_page_compressed
	from sys.dm_db_database_page_allocations(DB_ID(),object_id('ttt'), NULL, NULL, 'DETAILED') t
	where is_allocated = 1 --страница размещена
	order by index_id, is_iam_page desc, is_allocated desc, page_level desc, allocated_page_page_id



------------------------------------------------------------------------------------------------------------------------------------
/*пример forwarded records в куче*/
set statistics io on;
drop table if exists  ttt;
 CREATE TABLE [dbo].ttt
(
	id int identity(1,1),
	val varchar(4000)
);

INSERT INTO [dbo].ttt (val) VALUES (REPLICATE('a',50));

while (select count(*) from  sys.dm_db_database_page_allocations(DB_ID(),object_id('ttt'), NULL, NULL, 'DETAILED') t where is_allocated = 1) = 2
	INSERT INTO [dbo].ttt (val) VALUES (REPLICATE('a',50));;

select count(*) from ttt --Table 'ttt'. Scan count 1, logical reads 2

	SELECT sys.fn_PhysLocFormatter(t.%%physloc%%) RowID, *  FROM [dbo].ttt as t;
	select t.index_id, t.page_level, t.allocated_page_file_id FileID, t.allocated_page_page_id PageID, 
		t.is_iam_page, t.page_free_space_percent free_space, t.page_type_desc, t.is_page_compressed
		from sys.dm_db_database_page_allocations(DB_ID(),object_id('ttt'), NULL, NULL, 'DETAILED') t
		where is_allocated = 1 --страница размещена
		order by index_id, is_iam_page desc, is_allocated desc, page_level desc, allocated_page_page_id
	select DB_NAME(s.database_id) db_nm, s.index_type_desc, s.alloc_unit_type_desc, s.page_count
		, s.record_count, s.forwarded_record_count, s.compressed_page_count
		from sys.dm_db_index_physical_stats(db_id(),object_id('ttt'),NULL,NULL,'DETAILED') s

update [dbo].ttt set val = REPLICATE('a',500) where id/2*2 =id;

select count(*) from ttt --Table 'ttt'. Scan count 1, logical reads 56 (page count 5 + 51 forwarded records)

	SELECT sys.fn_PhysLocFormatter(t.%%physloc%%) RowID, *  FROM [dbo].ttt as t;
	select t.index_id, t.page_level, t.allocated_page_file_id FileID, t.allocated_page_page_id PageID, 
		t.is_iam_page, t.page_free_space_percent free_space, t.page_type_desc, t.is_page_compressed
		from sys.dm_db_database_page_allocations(DB_ID(),object_id('ttt'), NULL, NULL, 'DETAILED') t
		where is_allocated = 1 --страница размещена
		order by index_id, is_iam_page desc, is_allocated desc, page_level desc, allocated_page_page_id
	select DB_NAME(s.database_id) db_nm, s.index_type_desc, s.alloc_unit_type_desc, s.page_count
		, s.record_count, s.forwarded_record_count, s.compressed_page_count
		from sys.dm_db_index_physical_stats(db_id(),object_id('ttt'),NULL,NULL,'DETAILED') s

alter table [dbo].ttt rebuild;

select count(*) from ttt --Table 'ttt'. Scan count 1, logical reads 5

	SELECT sys.fn_PhysLocFormatter(t.%%physloc%%) RowID, *  FROM [dbo].ttt as t;
	select t.index_id, t.page_level, t.allocated_page_file_id FileID, t.allocated_page_page_id PageID, 
		t.is_iam_page, t.page_free_space_percent free_space, t.page_type_desc, t.is_page_compressed
		from sys.dm_db_database_page_allocations(DB_ID(),object_id('ttt'), NULL, NULL, 'DETAILED') t
		where is_allocated = 1 --страница размещена
		order by index_id, is_iam_page desc, is_allocated desc, page_level desc, allocated_page_page_id
	select DB_NAME(s.database_id) db_nm, s.index_type_desc, s.alloc_unit_type_desc, s.page_count
		, s.record_count, s.forwarded_record_count, s.compressed_page_count
		from sys.dm_db_index_physical_stats(db_id(),object_id('ttt'),NULL,NULL,'DETAILED') s

		

------------------------------------------------------------------------------------------------------------------------------------
/*split page*/

drop table if exists  ttt;
CREATE TABLE [dbo].ttt
(
	id int identity(1,1) PRIMARY KEY,
	val varchar(8000)
);

INSERT INTO [dbo].ttt (val) VALUES (REPLICATE('X', 4100));
INSERT INTO [dbo].ttt (val) VALUES (REPLICATE('y', 4100));

 	SELECT sys.fn_PhysLocFormatter(t.%%physloc%%) RowID, *  FROM [dbo].ttt as t;
	select t.index_id, t.page_level, t.allocated_page_file_id FileID, t.allocated_page_page_id PageID, 
		t.is_iam_page, t.page_free_space_percent free_space, t.page_type_desc, t.is_page_compressed
		from sys.dm_db_database_page_allocations(DB_ID(),object_id('ttt'), NULL, NULL, 'DETAILED') t
		where is_allocated = 1 --страница размещена
		order by index_id, is_iam_page desc, is_allocated desc, page_level desc, allocated_page_page_id
	select DB_NAME(s.database_id) db_nm, s.index_type_desc, s.index_level, s.alloc_unit_type_desc, s.page_count
		, s.record_count, s.avg_fragmentation_in_percent, s.avg_page_space_used_in_percent , s.compressed_page_count
		from sys.dm_db_index_physical_stats(db_id(),object_id('ttt'),NULL,NULL,'DETAILED') s

INSERT INTO [dbo].ttt (val) VALUES (REPLICATE('z', 100));
go 5

UPDATE [dbo].ttt SET val = REPLICATE('N', 4100) WHERE id = 5;

SELECT * FROM fn_dblog (NULL, NULL) WHERE [Operation] = N'LOP_DELETE_SPLIT';
 


------------------------------------------------------------------------------------------------------------------------------------
/*split page + rollback transaction*/

drop table if exists  ttt;
CREATE TABLE [dbo].ttt
(
	id int identity(1,1) PRIMARY KEY,
	val varchar(8000)
);

INSERT INTO [dbo].ttt (val) VALUES (REPLICATE('X', 4100)); 
go
INSERT INTO [dbo].ttt (val) VALUES (REPLICATE('y', 4100)); 
go
INSERT INTO [dbo].ttt (val) VALUES (REPLICATE('z', 100)); 
go 5

--index page = 1, data page = 2
SELECT [Transaction ID], Operation, Context, AllocUnitId, AllocUnitName, [Page ID], Description FROM fn_dblog (NULL, NULL) WHERE [Operation] = N'LOP_DELETE_SPLIT' and allocUnitId = (select allocation_unit_id from sys.partitions p join sys.allocation_units a on a.container_id = p.partition_id where object_id = OBJECT_ID('[dbo].ttt'));
 	SELECT sys.fn_PhysLocFormatter(t.%%physloc%%) RowID, *  FROM [dbo].ttt as t;
	select t.index_id, t.page_level, t.allocated_page_file_id FileID, t.allocated_page_page_id PageID, 
		t.is_iam_page, t.page_free_space_percent free_space, t.page_type_desc, t.is_page_compressed
		from sys.dm_db_database_page_allocations(DB_ID(),object_id('ttt'), NULL, NULL, 'DETAILED') t
		where is_allocated = 1 --страница размещена
		order by index_id, is_iam_page desc, is_allocated desc, page_level desc, allocated_page_page_id
	select DB_NAME(s.database_id) db_nm, s.index_type_desc, s.index_level, s.alloc_unit_type_desc, s.page_count
		, s.record_count, s.avg_fragmentation_in_percent, s.avg_page_space_used_in_percent , s.compressed_page_count
		from sys.dm_db_index_physical_stats(db_id(),object_id('ttt'),NULL,NULL,'DETAILED') s

begin tran
UPDATE [dbo].ttt SET val = REPLICATE('N', 4100) WHERE id = 5;
--index page = 1, data page = 3

rollback tran

 --index page = 1, data page = 3
 --данные откатились, но строки остались на новых страницах

