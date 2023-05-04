--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------
/*К каким объектам можно применить compression:
Table that is stored as a clustered index
Table stored as a heap
Partitioned tables and indexes
Non-clustered index
Indexed view

Типы:
ROW Compressoion - больше напоминает smart-storage (умное хранение), т.е. к примеру char и nchar хранятся без "лишних" пробелов в конце, число int = 3 (например) занимает не 4 байта, а 2байта т.п. 
PAGE Compression - полноценное сжание данных
COLUMNSTORE Compression - перестроение таблицы в виде колоночного индекса вместо классической ROWSTORE 
COLUMNSTORE_ARCHIVE Compression - еще более сжатый вариант COLUMNSTORE Compression*/



/*Displays the number of rows, disk space reserved, and disk space used by a table, indexed view, 
or Service Broker queue in the current database, or displays the disk space reserved and used by the whole database.
*/
exec sp_spaceused 'Books'
			
			--данные могут быть неточными, поэтому можно добавить параметр @updateusage
			EXEC sp_spaceused N'dbo.Books', @updateusage = N'TRUE'; --запуск операции DBCC UPDATEUSAGE для данного объекта

/*размер всех пользовательских таблиц в БД: имя, размер*/
select 
t.object_id obj_id
, SCHEMA_NAME(t.schema_id) sch_nm
, t.name tbl_nm
, sum(a.data_pages)*8/1024 data_MB
, sum(a.used_pages)*8/1024 used_MB
, sum(a.total_pages)*8/1024 total_MB
from sys.tables t
left join sys.partitions p
	on t.object_id = p.object_id
left join sys.allocation_units a
	on a.container_id = case when a.type in (1,3) then p.hobt_id
							when a.type = 2 then p.partition_id end
where is_ms_shipped <> 1 -- таблица создана не внутренним компонентом SQL Server
group by t.object_id, t.schema_id, t.name



/*размер всех пользовательских таблиц в БД: имя, партиция, размер, уровень сжатия*/
select 
t.object_id
, SCHEMA_NAME(t.schema_id) sch_nm
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
where is_ms_shipped <> 1 -- таблица создана не внутренним компонентом SQL Server
--and t.name like 'fok_2%'
group by t.object_id, t.schema_id, t.name, p.partition_number, p.data_compression_desc
order by tbl_nm


/*рассчетное значение размера таблицы/индекса до и после сжатия (либо до и после распаковки если сжатие уже применяется)
для этого используется аналог объекста создаваемого в tempdb, идет сжатие и приблизительный расчет*/
exec sys.sp_estimate_data_compression_savings
	@schema_name = N'dbo'
	, @object_name = N'contracts_old'
	, @index_id = NULL
	, @partition_number = NULL
	, @data_compression = N'ROW' --тип сжатия ROW, PAGE, COLUMNSTORE, COLUMNSTORE_ARCHIVE




/*сравнение разных типов сжатия (изначально сжатия нет!!!)*/
drop table if exists #temp;
if OBJECT_ID('tempdb..#temp') is not null drop table #temp;

create table #temp (obj_nm varchar(50), shm_nm varchar(50), idx_id int, prtn_nmb int, 
obj_sz_current_KB bigint, obj_sz_request_KB bigint, obj_smpl_sz_current_KB bigint, obj_smpl_sz_request_KB bigint, compression_type varchar(20));

insert into #temp (obj_nm, shm_nm, idx_id, prtn_nmb , obj_sz_current_KB, obj_sz_request_KB, obj_smpl_sz_current_KB, obj_smpl_sz_request_KB)
	exec sys.sp_estimate_data_compression_savings N'dbo', N'contracts_old', NULL, NULL, N'ROW'; --тип сжатия ROW, PAGE, COLUMNSTORE, COLUMNSTORE_ARCHIVE
update #temp set compression_type = 'ROW' where compression_type is NULL;
insert into #temp (obj_nm, shm_nm, idx_id, prtn_nmb, obj_sz_current_KB, obj_sz_request_KB, obj_smpl_sz_current_KB, obj_smpl_sz_request_KB)
	exec sys.sp_estimate_data_compression_savings N'dbo', N'contracts_old', NULL, NULL, N'PAGE'; --тип сжатия ROW, PAGE, COLUMNSTORE, COLUMNSTORE_ARCHIVE
update #temp set compression_type = 'PAGE' where compression_type is NULL;

select t.obj_nm, t.shm_nm, t.idx_id, t.prtn_nmb, 100-obj_sz_request_KB*100/obj_sz_current_KB compress_level, t.compression_type from #temp t;





			drop table if exists #temp

			create table #temp (
			obj_nm varchar(50)
			, shm_nm varchar(50)
			, idx_id int
			, partition_number int
			, obj_sz_current_KB bigint
			, obj_sz_request_KB bigint
			, obj_smpl_sz_current_KB bigint
			, obj_smpl_sz_request_KB bigint);

			insert into #temp
			exec sys.sp_estimate_data_compression_savings 'dbo','Demo',null, null, 'row';

			select * from #temp;











/*статистика использования индекса по операциям (на уровне листьев)*/
select db_name(i.database_id) db_nm
, object_name(i.object_id) obj_nm
, i.index_id idx_id
, i.partition_number prtn_nmb
, i.leaf_insert_count leaf_ins_cnt
, i.leaf_update_count leaf_upd_cnt
, i. leaf_delete_count leaf_del_cnt 
, i.leaf_ghost_count leaf_ghst_cnt
, i.leaf_page_merge_count leaf_mrg_cnt
, i.range_scan_count scn_cnt
, i.singleton_lookup_count sek_cnt
, i.page_io_latch_wait_count pg_io_lath_cnt
, i.page_io_latch_wait_in_ms pg_io_lath_ms
, iif(i.page_io_latch_wait_count=0, 0, i.page_io_latch_wait_in_ms/i.page_io_latch_wait_count) avg_pg_io_lath_ms
from sys.dm_db_index_operational_stats (db_id(),null,null,null) i
where OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
and (i.leaf_insert_count + i.leaf_update_count + i. leaf_delete_count + i.leaf_ghost_count + 
	i.leaf_page_merge_count + i.range_scan_count + i.singleton_lookup_count) != 0
order by avg_pg_io_lath_ms desc

			/*статистика использования индекса по операциям в процентах (на уровне листьев)*/
			select db_name(i.database_id) db_nm
			, object_name(i.object_id) obj_nm
			, i.index_id idx_id
			, i.partition_number prtn_nmb
			, i.leaf_insert_count*100/(i.leaf_insert_count + i.leaf_update_count + i. leaf_delete_count + i.leaf_ghost_count + i.leaf_page_merge_count + i.range_scan_count + i.singleton_lookup_count) ins_prcnt
			, i.leaf_update_count*100/(i.leaf_insert_count + i.leaf_update_count + i. leaf_delete_count + i.leaf_ghost_count + i.leaf_page_merge_count + i.range_scan_count + i.singleton_lookup_count) upd_prcnt
			, i.leaf_delete_count*100/(i.leaf_insert_count + i.leaf_update_count + i. leaf_delete_count + i.leaf_ghost_count + i.leaf_page_merge_count + i.range_scan_count + i.singleton_lookup_count) del_prcnt 
			, i.leaf_ghost_count*100/(i.leaf_insert_count + i.leaf_update_count + i. leaf_delete_count + i.leaf_ghost_count + i.leaf_page_merge_count + i.range_scan_count + i.singleton_lookup_count) ghst_prcnt
			, i.leaf_page_merge_count*100/(i.leaf_insert_count + i.leaf_update_count + i. leaf_delete_count + i.leaf_ghost_count + i.leaf_page_merge_count + i.range_scan_count + i.singleton_lookup_count) mrg_prcnt
			, i.range_scan_count*100/(i.leaf_insert_count + i.leaf_update_count + i. leaf_delete_count + i.leaf_ghost_count + i.leaf_page_merge_count + i.range_scan_count + i.singleton_lookup_count) scn_prcnt
			, i.singleton_lookup_count*100/(i.leaf_insert_count + i.leaf_update_count + i. leaf_delete_count + i.leaf_ghost_count + i.leaf_page_merge_count + i.range_scan_count + i.singleton_lookup_count) sek_prcnt

			, (i.leaf_insert_count + i.leaf_update_count + i. leaf_delete_count + i.leaf_ghost_count + i.leaf_page_merge_count)*100/(i.leaf_insert_count + i.leaf_update_count + i. leaf_delete_count + i.leaf_ghost_count + i.leaf_page_merge_count + i.range_scan_count + i.singleton_lookup_count) IUD_prcnt --insert, update, delete
			, (i.range_scan_count + i.singleton_lookup_count)*100/(i.leaf_insert_count + i.leaf_update_count + i. leaf_delete_count + i.leaf_ghost_count + i.leaf_page_merge_count + i.range_scan_count + i.singleton_lookup_count) SS_prcnt --scan, seek

			, i.page_io_latch_wait_count pg_io_lath_prcnt
			, i.page_io_latch_wait_in_ms pg_io_lath_ms
			, iif(i.page_io_latch_wait_count=0, 0, i.page_io_latch_wait_in_ms/i.page_io_latch_wait_count) avg_pg_io_lath_ms
			from sys.dm_db_index_operational_stats (db_id(),null,null,null) i
			where OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
			and (i.leaf_insert_count + i.leaf_update_count + i. leaf_delete_count + i.leaf_ghost_count + 
				i.leaf_page_merge_count + i.range_scan_count + i.singleton_lookup_count) != 0
			order by avg_pg_io_lath_ms desc


select 
db_name(i.database_id) db_nm
, o.name tbl_nm, x.index_id idx_id, x.name idx_nm, i.partition_number
, i.leaf_update_count*100/(i.leaf_insert_count + i.leaf_update_count + i. leaf_delete_count + i.leaf_ghost_count + 
	i.leaf_page_merge_count + i.range_scan_count + i.singleton_lookup_count) prcnt_upd --относительное кол-во операций обновления для индекса, если много, то сжатие не выгодно
, i.range_scan_count*100/(i.leaf_insert_count + i.leaf_update_count + i. leaf_delete_count + i.leaf_ghost_count + 
	i.leaf_page_merge_count + i.range_scan_count + i.singleton_lookup_count) prcnt_scn --относительное кол-во операций сканирования индекса, если много, то сжатие выгодно
, i.page_io_latch_wait_count
, i.page_io_latch_wait_in_ms
from sys.dm_db_index_operational_stats (db_id(),null,null,null) i
join sys.objects o on o.object_id = i.object_id
join sys.indexes x on x.object_id =i.object_id and x.index_id = i.index_id
where (i.leaf_insert_count + i.leaf_update_count + i. leaf_delete_count + i.leaf_ghost_count + 
	i.leaf_page_merge_count + i.range_scan_count + i.singleton_lookup_count) !=0
		and OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
		order by 1





--------------------------------------------------------------------------------------------
------------------------------------------Maintaince----------------------------------------
--------------------------------------------------------------------------------------------
/*сжатие происходит на уровне partition (все allocation units в это partition будут сжаты(?))
уровни сжатия: NONE -> ROW -> PAGE -> COLUMNSTORE -> COLUMNSTORE_ARCHIVE
*/

/*row compression*/
ALTER TABLE [dbo].[Sums_row] REBUILD PARTITION = ALL
	WITH (DATA_COMPRESSION = ROW); GO

/*page compression*/
ALTER TABLE [dbo].fok_20190213 REBUILD PARTITION = ALL
	WITH (DATA_COMPRESSION = PAGE);	GO
	
/*начиная с 2014*/
ALTER TABLE [dbo].[Sums_row] REBUILD PARTITION = ALL
	WITH (DATA_COMPRESSION = COLUMNSTORE); GO

/*начиная с 2014*/
ALTER TABLE [dbo].[Sums_row] REBUILD PARTITION = ALL
	WITH (DATA_COMPRESSION = COLUMNSTORE_ARCHIVE); GO

/*colunmstore*/
CREATE CLUSTERED COLUMNSTORE INDEX CCI_20180501 ON 20180501
	WITH (DATA_COMPRESSION = COLUMNSTORE); -- c 2014
GO

/*colunmstore*/
CREATE CLUSTERED COLUMNSTORE INDEX CCX_cs_arch ON cs_arch
	WITH (DATA_COMPRESSION = COLUMNSTORE_ARCHIVE);
GO



/*сжатие нескольких объектов БД*/
DECLARE @schm_nm nvarchar(50),
		@tbl_nm nvarchar(50),
		@str nvarchar(4000)

DECLARE cur CURSOR
FOR select name from sys.tables where name like 'fok_2%'

OPEN cur;
FETCH NEXT FROM cur INTO @tbl_nm;

WHILE @@fetch_status = 0
BEGIN
	SET @str = 'ALTER TABLE ' + @tbl_nm + ' REBUILD PARTITION = ALL
		WITH (DATA_COMPRESSION = PAGE)'
	EXEC (@str);

	FETCH NEXT 	FROM cur INTO @tbl_nm;
END

CLOSE cur;
DEALLOCATE cur;


