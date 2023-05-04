/*table types:
1. Disk-based - simple tables (store on disk in 8kb pages)
2. Memory-optimized (2014) - tables using for OLTP (primary storage is main memory and/not with a second copy on disk)
3. Partitioned tables - different parts of tables store in different file groups
4. Temporary tables (#-local, ##-global) - store in tempdb
5. Table variables (@) - store in tempdb
6. System tables - use in DMVs
7. File tables - spatial type for storage BLOB-data (unstructured data)
8. Temporal tables - (2016) use for trace changes in table

*/

--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------
/*список всех пользовательских(!) таблиц в БД*/
select * from sys.tables where is_ms_shipped <> 1 -- таблица создана не внутренним компонентом SQL Server
	select * from sys.objects where type_desc = 'USER_TABLE' and is_ms_shipped <> 1 
	select * from sys.all_objects where type_desc = 'USER_TABLE' and is_ms_shipped <> 1

select * from sys.internal_tables


--общая информация о таблицах
select SCHEMA_NAME(t.schema_id) shm_nm
, t.name tbl_nm
, t.object_id obj_id
, t.create_date
, t.max_column_id_used col_cnt
, t.is_filetable
, t.is_memory_optimized
, t.temporal_type_desc
, t.history_table_id
 from sys.tables t where is_ms_shipped <> 1
 order by shm_nm, tbl_nm


----------------------------------------------------------------Storage----------------------------------------------------------------
select * from sys.partitions				--секции
select * from sys.dm_db_partition_stats
select * from sys.system_internals_partitions	--для Columnstore index
select * from sys.allocation_units			--единицы распределения (IN_ROW_DATA, ROW_OVERFLOW_DATA, LOB_DATA)

/*размер объекта*/
exec sp_spaceused 'dbo.Books'


---------------------------------------------
/*общий размер пользовательских таблиц в БД*/
---------------------------------------------
--через ХП
drop table if exists #temp_size;
create table #temp_size(name varchar(255), [rows] varchar(255), reserved varchar(255), [data] varchar(255), index_size varchar(255), unused varchar(255));
insert into #temp_size
	exec sp_MSforeachtable N'exec sp_spaceused''?'''
select * from #temp_size
	order by cast(replace(reserved,'KB','') as bigint) desc
	--order by CAST([rows] as bigint) desc
drop table #temp_size;


/*
для sp_spaceused:
reserved	- зарезервировано для данных + индексов
data		- "чистые данные" в таблице (размер кучи или CI)
index_size	- суммарный размер NCIs
unused		- зарезервировано, но не используется

для sys.allocation_units:
total_pages - кол-во выделенных страниц для единицы распределения (общее число зарезервированных страниц для харанения и управления данными)
used_pages - кол-во используемых страниц для единицы распределения (страницы с данными + страницы управления данными (IAM, промежут. страницы индекса))
data_pages - кол-во страниц с данными (in-row data, LOB data, row-owerflow data) (сюда не включены внутренние страницы индекса и страницы управления размещением)

для sys.dm_db_partition_stats:
reserved_page_count - зарезервировано для таблицы / индексов
used_page_count - используется таблицей / индексом

sp_spaceused		sys.allocation_units:
reserved		=	sum(total)
data			=	sum(data)				=	sum(data_pages) + sum(text_used)
index_size		=	sum(used) - sum(data)
unused			=	sum(total) - sum(used)
*/


/*расчет размера объектов (таблица + индексы) через sys.dm_db_partition_stats*/
SELECT
t.object_id
, SCHEMA_NAME(t.schema_id) shm_nm
, t.name tbl_nm
, sum(iif(ps.index_id in (0,1), ps.row_count, 0)) rows_cnt
, sum(ps.reserved_page_count)*8/1024 total_MB
, ' ' ' '
, sum(ps.used_page_count)*8/1024 used_MB
, (sum(ps.reserved_page_count) - sum(ps.used_page_count))*8/1024 unused_MB
, ' ' ' '
, sum(iif(ps.index_id in (0, 1, 255), in_row_data_page_count + lob_used_page_count + row_overflow_used_page_count, 0))*8/1024 data_MB		
, (sum(ps.used_page_count) - sum(iif(ps.index_id in (0, 1, 255), in_row_data_page_count + lob_used_page_count + row_overflow_used_page_count, 0)))*8/1024 index_MB
from sys.tables t
join sys.dm_db_partition_stats ps
	on t.object_id = ps.object_id
where t.is_ms_shipped <> 1 -- таблица создана не внутренним компонентом SQL Server
--and t.name  = 'param_info_cut'
--and p.index_id in (0, 1, 255) --только таблица, без ндексов
group by t.object_id, t.schema_id, t.name
order by total_MB desc, rows_cnt desc

			/*расчет размера объектов (таблица + индексы) через sys.allocation_units*/
			select 
			t.object_id
			, SCHEMA_NAME(t.schema_id) shm_nm
			, t.name tbl_nm
			, sum(iif(p.index_id in (0,1), p.rows, 0))/count(distinct a.type) rows_cnt --кол-во строк в таблице
			, sum(a.total_pages)*8/1024 total_MB --всего зарезервировано (allocated, распределено) для объекта (таблица + индексы) (данные + системные IAM страницы)
			, ' ' ' '
			, sum(a.used_pages)*8/1024 used_MB --используется для объекта (таблица + индексы)
			, (sum(a.total_pages) - sum(a.used_pages))*8/1024 unused_MB --зарезервировано, но не используется для объекта
			, ' ' ' '
			, sum(iif(p.index_id in (0, 1, 255), a.data_pages, 0))*8/1024 data_MB --размер "чистых" данных (In-row data, LOB data, Row-overflow data) (255 = Entry for tables that have text or image data), размер кучи либо листового уровня CI
			, sum(iif(p.index_id not in (0, 1, 255), a.total_pages, 0))*8/1024 index_MB --суммарный размер NCI индексов
			--, (sum(a.used_pages) - sum(iif(p.index_id in (0, 1, 255), a.data_pages, 0)))*8/1024 --sum(used) - sum(data) where indid in (0, 1, 255)
			, (sum(a.used_pages)-sum(iif(p.index_id in (0, 1, 255), a.data_pages, 0))-sum(iif(p.index_id not in (0, 1, 255), a.total_pages, 0)))*8/1024 sys_data_MB --системные данные (т.е. страницы внутреннего индекса и страницы управления распределением)
			from sys.tables t
			left join sys.partitions p
				on t.object_id = p.object_id
			left join sys.allocation_units a
				on a.container_id = case when a.type in (1,3) then p.hobt_id
										when a.type = 2 then p.partition_id end
			where t.is_ms_shipped <> 1 -- таблица создана не внутренним компонентом SQL Server
			--and t.name  = 'param_info_cut'
			--and p.index_id in (0, 1, 255) --только таблица, без индексов
			group by t.object_id, t.schema_id, t.name
			order by total_MB desc, rows_cnt desc


/*расчет размера объекта (таблица + индексы) по партициям: имя, партиция, размер, уровень сжатия*/
select 
t.object_id
, SCHEMA_NAME(t.schema_id) shm_nm
, t.name tbl_nm
, p.partition_number
, p.data_compression_desc [compression]
, sum(a.data_pages)*8/1024 data_MB
, sum(a.used_pages)*8/1024 used_MB
, sum(a.total_pages)*8/1024 total_MB
from sys.tables t
left join sys.partitions p
	on t.object_id = p.object_id
left join sys.allocation_units a
	on a.container_id = case when a.type in (1,3) then p.hobt_id
							when a.type = 2 then p.partition_id end
where t.is_ms_shipped <> 1 -- таблица создана не внутренним компонентом SQL Server
--and p.index_id in (0, 1, 255) --только таблица, без ндексов
group by t.object_id, t.schema_id, t.name, p.partition_number, p.data_compression_desc
order by tbl_nm



----------------------------------------------------------------Table Structure----------------------------------------------------------------
select * from sys.systypes									--все типы данных на сервере
select * from sys.types										--все типы данных на сервере

select * from sys.columns 									--все колонки
select * from sys.types										--типы данных
select * from sys.extended_properties						--расширенные параметры




select * from sys.objects where type in ('PK', 'FK', 'C', 'D', 'UQ') --ограничения для таблиц
	select * from sys.all_objects where type in ('PK', 'FK', 'C', 'D', 'UQ') --ограничения для таблиц
select * from sys.check_constraints							--ограничение CHECK
select * from sys.key_constraints							--ограничение PK, UNIQUE
select * from sys.foreign_keys								--ограничение FK
select * from sys.default_constraints						--ограничениe DEFAULT
select * from INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE	--поля таблицы, кот. используются в ограничениях

/*общая информация по полям указанной таблицы*/
select DB_NAME() db_nm
, SCHEMA_NAME(t.schema_id) shm_nm
, t.name tbl_nm
, c.name cln_nm
, p.name tp_nm
--, c.*
, iif(p.name in ('nchar', 'nvarchar'), c.max_length/2,c.max_length) max_length
, c.precision
, c.scale
, iif(c.is_nullable = 0,'No','Yes') is_nullable
, iif(c.is_identity = 0,'No','Yes') is_identity
from sys.tables t
left join sys.columns c on t.object_id = c.object_id
left join sys.types	p on c.user_type_id = p.user_type_id
where t.is_ms_shipped <> 1 -- таблица создана не внутренним компонентом SQL Server
and t.name  in ('Books')
order by t.name, c.column_id



--ограничения на таблице (общие сведения)
select DB_NAME() db_nm
, SCHEMA_NAME(t.schema_id) shm_nm
, t.name tbl_nm
, o.name cnstr_nm
, o.type
from sys.tables t
join sys.objects o
	on t.object_id = o.parent_object_id
where t.is_ms_shipped <> 1 -- таблица создана не внутренним компонентом SQL Server
and t.name  in ('Person')
and o.type in ('PK', 'FK', 'C', 'D', 'UQ')
order by t.name

			--ограничения на таблице (детально), если ограничений нет, то в выборку не попадает
			select DB_NAME() db_nm
			, SCHEMA_NAME(t.schema_id) shm_nm
			, t.name tbl_nm
			, c.name cnstr_nm
			, c.type cnstr_tp
			, c.definition COLLATE Latin1_General_CI_AS [definition]
			from sys.tables t
			join sys.check_constraints c
				on t.object_id = c.parent_object_id
			where t.is_ms_shipped <> 1 -- таблица создана не внутренним компонентом SQL Server
			union
			select DB_NAME() db_nm
			, SCHEMA_NAME(t.schema_id) shm_nm
			, t.name tbl_nm
			, d.name cnstr_nm
			, d.type cnstr_tp
			, c.name + ' = ' + substring(d.definition, 2, LEN(d.definition)-2) [definition]
			from sys.tables t
			join sys.default_constraints d
				on t.object_id = d.parent_object_id
			left join sys.columns c
				on c.object_id = t.object_id and c.column_id = d.parent_column_id
			where t.is_ms_shipped <> 1 -- таблица создана не внутренним компонентом SQL Server
			union
			select DB_NAME() db_nm
			, SCHEMA_NAME(t.schema_id) shm_nm
			, t.name tbl_nm
			, k.name cnstr_nm
			, k.type cnstr_tp
			, ''
			from sys.tables t
			join sys.key_constraints k
				on t.object_id = k.parent_object_id
			where t.is_ms_shipped <> 1 -- таблица создана не внутренним компонентом SQL Server
			union
			select DB_NAME() db_nm
			, SCHEMA_NAME(t.schema_id) shm_nm
			, t.name tbl_nm
			, f.name cnstr_nm
			, f.type cnstr_tp
			, 'del: ' + f.delete_referential_action_desc + ',   upd: ' + f.update_referential_action_desc
			from sys.tables t
			join sys.foreign_keys f
				on t.object_id = f.parent_object_id
			where t.is_ms_shipped <> 1 -- таблица создана не внутренним компонентом SQL Server
			order by 1,2,3





--------------------------------------------------------------------------------------------
-----------------------------------------Statistics-----------------------------------------
--------------------------------------------------------------------------------------------
/*сведения о размере и фрагментации данных и индексов таблицы или представления
для индекса: строка для каждого уровня B-tree
для кучи: строка для каждой единицы распределения (allocation unit)
database_id, object_id, index_id, partition_number, mode [LIMITED | SAMPLED | DETAILED]
LIMITED - сканирование только корневого и промежуточных уровней B-tree (но не листового уровня)
SAMPLED - сканирование 1% листового уровня
DETAILED - сканирование всего индекса (всех уровней)
*/
select * from sys.dm_db_index_physical_stats(db_id(),NULL,NULL,NULL,'DETAILED') 

/*статистика о вводе-выводе низкого уровня, блокировки для каждой секции таблицы*/
select * from sys.dm_db_index_operational_stats (db_id(),NULL,NULL,NULL)
           
/*статистика по операциям с индексами: scan, seek, lookup, update*/
select * from sys.dm_db_index_usage_stats
select * from sys.dm_db_fts_index_physical_stats



--------------------------------------------
/*статистика физического состояния таблицы*/
--------------------------------------------
select DB_NAME(s.database_id) db_nm
, SCHEMA_NAME(t.schema_id) shm_nm
, t.name tbl_nm
, s.index_type_desc
, s.partition_number
, s.alloc_unit_type_desc
, s.page_count
, s.compressed_page_count cmprs_page_cnt
, s.record_count --в общем случае не равно row_count (число записей не равно числу строк, строка может содержать несколько записей)
, s.forwarded_record_count frwd_record_cnt
, s.ghost_record_count ghst_record_cnt
--, cast(s.forwarded_record_count * 1./s.record_count as decimal(4,2)) pers_ford_rec
, s.avg_fragmentation_in_percent ext_frgmnt --логич. (внешняя) фрагментация, нужен параметр DETAILED
, 100 - s.avg_page_space_used_in_percent int_frgmnt --внутренняя фрагментация (% заполнения страницы)
--, s.*
from sys.tables t
left join sys.dm_db_index_physical_stats(db_id(),NULL,NULL,NULL,'DETAILED') s
	on s.object_id = t.object_id
where  t.is_ms_shipped <> 1 -- таблица создана не внутренним компонентом SQL Server
and s.index_id in (0,1) --только таблица (heap/CI), без индексов
--and s.page_count > 1
--and s.avg_page_space_used_in_percent < 50

order by t.name

			--то же самое, возможно будет быстрее при больших объеах данных (на небольщих объемах ведет себя хуже)
			; with heap as (
				select t.schema_id, t.name, s.* from sys.tables t join sys.indexes i on t.object_id = i.object_id and i.index_id = 0
				cross apply sys.dm_db_index_physical_stats(db_id(),t.object_id,0,NULL,'DETAILED') s)
				, ci as (
				select t.schema_id, t.name, s.* from sys.tables t join sys.indexes i on t.object_id = i.object_id and i.index_id = 1
				cross apply sys.dm_db_index_physical_stats(db_id(),t.object_id,1,NULL,'DETAILED') s)
				, uni as (
				select * from heap
				union
				select * from ci)
			select DB_NAME(t.database_id) db_nm
			, SCHEMA_NAME(t.schema_id) shm_nm
			, t.name tbl_nm
			, t.index_type_desc
			, t.partition_number
			, t.alloc_unit_type_desc
			, t.page_count
			, t.compressed_page_count cmprs_page_cnt
			, t.record_count --в общем случае не равно row_count (число записей не равно числу строк, строка может содержать несколько записей)
			, t.forwarded_record_count frwd_record_cnt
			, t.ghost_record_count ghst_record_cnt
			--, cast(s.forwarded_record_count * 1./s.record_count as decimal(4,2)) pers_ford_rec
			, t.avg_fragmentation_in_percent ext_frgmnt --логич. (внешняя) фрагментация, нужен параметр DETAILED
			, 100 - t.avg_page_space_used_in_percent int_frgmnt --внутренняя фрагментация (% заполнения страницы)
			--, s.*
			from uni t
			where t.index_level = 0 -- только кача и листовой уровень индекса
			
			--используем врем таблицу
			select * into #t from sys.dm_db_index_physical_stats(db_id(),NULL,NULL,NULL,'DETAILED')
			

--------------------------------------------------------
/*статистика по времени последнего обращения к таблице*/
--------------------------------------------------------
; with cte as (
	select DB_NAME(s.database_id) db_nm
	, SCHEMA_NAME(t.schema_id) shm_nm
	, t.name tbl_nm
	, last_user_action = (select MAX(last_user_action) from (values (last_user_seek),(last_user_scan),(last_user_lookup), (last_user_update)) as user_dts (last_user_action))
	, last_system_action = (select MAX(last_system_action) from (values (last_system_seek),(last_system_scan),(last_system_lookup), (last_system_update)) as system_dts (last_system_action))
	from sys.tables t
	left join sys.dm_db_index_usage_stats s
		on DB_ID() = s.database_id
		and t.object_id = s.object_id
	 where  t.is_ms_shipped <> 1 -- таблица создана не внутренним компонентом SQL Server
)
select * from cte c
where c.last_system_action is not null or c.last_user_action is not null
order by db_nm, shm_nm, tbl_nm





--------------------------------------------------------------------------------------------
-----------------------------------------Maintaince-----------------------------------------
--------------------------------------------------------------------------------------------

/*удаление нескольких таблиц*/
use <db_nm>

DECLARE @shm_nm nvarchar(50),
		@tbl_nm nvarchar(50),
		@str nvarchar(4000)

DECLARE cur CURSOR
FOR select SCHEMA_NAME(schema_id), name from sys.tables
where SCHEMA_NAME(schema_id)!= 'dbo'

OPEN cur;
FETCH NEXT FROM cur INTO @shm_nm,@tbl_nm;

WHILE @@fetch_status = 0
BEGIN
	SET @str = 'drop  TABLE [' + @shm_nm  + '].[' + @tbl_nm +']' 
	EXEC (@str);
	print @str

	FETCH NEXT FROM cur INTO @shm_nm,@tbl_nm;
END

CLOSE cur;
DEALLOCATE cur;





/*ALTER TABLE*/

create table temp (id int);
/*добавить колонку в таблицу*/
alter table temp add val int null, num tinyint not null;
/*изменить свойства колонки в таблице*/
alter table temp alter column val bigint not null;
/*удалить колонку в таблицу*/
alter table temp drop column val; --можно перечислить несколько
/*добавить ограничение в таблицу*/
alter table temp add constraint PK_Temp primary key clustered (val);
/*удалить ограничение из таблицу*/
alter table temp drop constraint PK_Temp;
---Переименование таблицы/столбца---
EXEC sp_RENAME 'Employees.Name', 'Surname'



---Очистка таблицы (удаление всех записей)---
TRUNCATE TABLE Employees
DELETE Employees





--------------------------------------------------------------------------------------------------------------------------------------------------------------
/*ограничения на таблице*/

	---Ограничение целостности---
		---PRYMARY KEY---
	CONSTRAINT PK_Employees PRIMARY KEY (ID) --в каталог Ключи/Keys и Индексы/Indexes
	CONSTRAINT PK_Employees PRIMARY KEY (поле1, поле2,...)
	
		---FOREING KEY---
	CONSTRAINT FK_Employees_DeprtmentID FOREIGN KEY (DeprtmentID) REFERENCES Departments(ID)-- --в каталог Ключи/Keys
	CONSTRAINT FK_Employees_DeprtmentID FOREIGN KEY (поле1, поле2,...) REFERENCES Departments(поле1, поле2,...)
	
		---UNIQUE---
	CONSTRAINT UQ_Employees_email UNIQUE (email)--в каталог Ключи/Keys и Индексы/Indexes
	CONSTRAINT UQ_Employees_email UNIQUE (поле1, поле2,...)
	
		---DEFAULT---
	CONSTRAINT DF_Employees_RegDate DEFAULT GETDATE() FOR RegDate --в каталог Ограничения/Constrains
	--задается по-одному ограничению в скрипте, удалять также через скрипт
	
		---CHECK---
	CONSTRAINT CK_Employees_Birthday CHECK  (Birthday > '1950-01-01 00:00:00.000') --в каталог Ограничения/Constrains
	
		---При создании таблицы---
CREATE TABLE Employees (
	...,
	CONSTRAINT PK_Employees PRIMARY KEY (ID),
	CONSTRAINT FK_Employees_DeprtmentID FOREIGN KEY (DeprtmentID) REFERENCES Departments(ID),
	CONSTRAINT UQ_Employees_email UNIQUE (email),
	CONSTRAINT DF_Employees_RegDate DEFAULT GETDATE() FOR RegDate,
	CONSTRAINT CK_Employees_Birthday CHECK  (Birthday > '1950-01-01 00:00:00.000')
	)
	
CREATE TABLE Employees (
	ID int NOT NULL CONSTRAINT PK_Employees PRIMARY KEY,
	RegDate datetime DEFAULT GETDATE(),
	...)
	
		---При изменении таблицы---	
ALTER TABLE Employees ADD CONSTRAINT PK_Employees PRIMARY KEY (ID)												
ALTER TABLE Employees ADD CONSTRAINT FK_Employees_DeprtmentID FOREIGN KEY (DeprtmentID) REFERENCES Departments(ID) --ON DELETE/UPDATE CASCADE
ALTER TABLE Employees ADD CONSTRAINT UQ_Employees_email UNIQUE (email,Name)
ALTER TABLE Employees ADD CONSTRAINT DF_Employees_RegDate DEFAULT GETDATE() FOR RegDate
ALTER TABLE Employees ADD CONSTRAINT CK_Employees_Birthday CHECK  (Birthday > '1950-01-01 00:00:00.000') 
ALTER TABLE with NOcheck --не проверять данных в уже заполненной таблице

		---Без наименования ограничений (лучше не делать)---
ALTER TABLE Employees ADD UNIQUE (email)
ALTER TABLE Employees ADD CHECK  (Birthday > '1950-01-01 00:00:00.000')
ALTER TABLE Employees ADD DEFAULT GETDATE() FOR RegDate
													
	---Удаление ограничения---
ALTER TABLE Employees DROP CONSTRAINT PK_Employees --для любого ограничения

--------------------------------------------------------------------------------------------------------------------------------------------------------------

/*перестроение HEAP-таблиц*/
DECLARE @db_nm nvarchar(50),
		@shm_nm nvarchar(50),
		@tbl_nm nvarchar(50),
		@str nvarchar(4000)

DECLARE cur CURSOR
FOR select DB_NAME(s.database_id) db_nm
	, SCHEMA_NAME(t.schema_id) shm_nm
	, t.name tbl_nm
	from sys.tables t
	left join sys.dm_db_index_physical_stats(db_id(),NULL,NULL,NULL,'DETAILED') s
		on s.object_id = t.object_id
	where  t.is_ms_shipped <> 1 -- таблица создана не внутренним компонентом SQL Server
	and s.index_id in (0) --только таблица, без индексов
	group by s.database_id, t.schema_id, t.name
	having sum(s.page_count) > 10 and (sum(s.forwarded_record_count) > 0 or avg(s.avg_fragmentation_in_percent) > 30)
	order by sum(s.page_count)

OPEN cur;
FETCH NEXT FROM cur INTO @db_nm, @shm_nm, @tbl_nm;

WHILE @@fetch_status = 0
BEGIN
	SET @str = 'ALTER TABLE [' + @db_nm  + '].[' + @shm_nm  + '].[' + @tbl_nm +'] REBUILD;' 
	EXEC (@str);
	print @str

	FETCH NEXT FROM cur INTO @db_nm, @shm_nm, @tbl_nm;
END

CLOSE cur;
DEALLOCATE cur;


--------------------------------------------------------------------------------------------
-------------------------------------Forwarding Records-------------------------------------
--------------------------------------------------------------------------------------------

/*посик всех таблиц, у которых есть Forwarding Records*/
select DB_NAME(s.database_id) db_nm
, t.name
, s.index_type_desc
, s.alloc_unit_type_desc
, s.page_count
, s.record_count
, s.forwarded_record_count
, cast(s.forwarded_record_count * 1./s.record_count as decimal(4,2)) pers_ford_rec
, s.compressed_page_count
from sys.dm_db_index_physical_stats(db_id(),NULL,NULL,NULL,'SAMPLED') s
left join sys.tables t
	on s.object_id = t.object_id
where index_id = 0 and forwarded_record_count > 0


