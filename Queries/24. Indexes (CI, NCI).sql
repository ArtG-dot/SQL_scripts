--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------
/*!!! nonunique nonclustered index хранит ключ кластерного индекса либо RID на ПРОМЕЖУТОЧНЫХ уровнях индекса, 
это нужно для уникальностизначений ключа некластерного индекса !!!
в конце листа будет проверка. как итог:
кол-во страниц для nonunique NCI и unique NCI существенно(!!!) отличается только на промежуточных уровнях 
(при наличии большого либо составного ключа кластерного индекса).
кол-во страниц на листовом уровне не отличаются.

Возможно влияние на размер индекса только при очень больших объемах NCI и наличия большого ключа кластерного индекса
Но все таки лучше корректно задавать параметр unique при создании NCI!!!
*/
/*при использовании каскадного удаления, нужно создавать индекс (NC) на внешних ключах для быстрого поиска нужного значения*/

select * from sys.tables
select * from sys.indexes WHERE object_id = OBJECT_ID('pers_info'); --индексы в таблице;
select * from sys.index_columns --WHERE object_id = OBJECT_ID('ap_reqwest'); --колонки в индексах;
select * from sys.columns;
select * from sys.types;



--------------------
/*общая информация*/
--------------------
--общая информация для таблицы
exec sp_help 'dbo.Books'
--все индексы на таблице
exec sp_helpindex 'dbo.Books'


/*All indexes in DB*/
--если индекс отключен, то это не отображается в SSMS, только в DMV и свойствах самого индекса
select t.object_id obj_id, t.name tbl_nm, SCHEMA_NAME(t.schema_id) shm_nm, t.type_desc, i.is_disabled
, i.index_id idx_id, i.name idx_nm, i.type_desc, i.is_unique, i.fill_factor, i.has_filter, i.filter_definition
from sys.tables t
left join sys.indexes i
	on i.object_id = t.object_id
where t.is_ms_shipped = 0 
and index_id >= 1 --только индексы, исключаем HEAP
order by obj_id, idx_id;



/*All indexes in DB + index's columns*/ --доделать для included columns
select t.name 'table name', t.object_id, 
 i.index_id, isnull(i.name,'HEAP') 'index name', i.fill_factor, i.type_desc,i.is_unique,
 ic.index_column_id, c.name 'column name', ct.name 'column type'
from sys.tables t
left join sys.indexes i
	on i.object_id = t.object_id
left join sys.index_columns ic
	on ic.object_id = i.object_id
	and ic.index_id = i.index_id
left join sys.columns c
	on c.object_id = t.object_id
	and c.column_id = ic.column_id
left join sys.types ct
	on ct.user_type_id = c.user_type_id
where  t.is_ms_shipped = 0 
and i.index_id >= 1
--and i.object_id = OBJECT_ID('syscommittab')
order by t.name, i.index_id, ic.index_column_id;


			--доделать для included columns!!!!!!!!!!!!!!!!!
			; with cte as (
				select t.name tbl_nm, t.object_id obj_id, 
				 i.index_id idx_id, isnull(i.name,'HEAP') idx_nm, i.fill_factor, i.type_desc,i.is_unique,
				ic.index_column_id, ic.key_ordinal, ic.is_included_column, c.name clm_nm
				from sys.tables t
				left join sys.indexes i
					on i.object_id = t.object_id
				left join sys.index_columns ic
					on ic.object_id = i.object_id
					and ic.index_id = i.index_id
				left join sys.columns c
					on c.object_id = t.object_id
					and c.column_id = ic.column_id
				where  t.is_ms_shipped = 0 
				and i.index_id >= 1
				--order by t.name, i.index_id, ic.index_column_id
			)
			select distinct tbl_nm, obj_id, idx_id, idx_nm, fill_factor, type_desc, is_unique,
			(select max(t.index_column_id) 
			from cte t 
				where c.obj_id = t.obj_id 
					and c.idx_id = t.idx_id) clm_cnt,
			stuff((select ',  ['+ clm_nm + ']'
				from cte t 
				where c.obj_id = t.obj_id 
					and c.idx_id = t.idx_id
					and t.is_included_column = 0
				order by index_column_id
				for xml path('')),1,1,'') key_clms
			from cte c
			order by tbl_nm, idx_id



--------------------------------------------------------------------------------------------
-----------------------------------------Using index----------------------------------------
--------------------------------------------------------------------------------------------

select * from sys.dm_db_index_operational_stats (DB_ID(),NULL,NULL,NULL) o;		--server level, детальная статистика использования индекса (lower-level I/O, locking, latching + access method activity for each partition of a table or index: insert, delete, update, rangescan, lookup, etc.)
select * from sys.dm_db_index_usage_stats u										--server level, статистика использования индекса (seek, scan, lookup, update)
select * from sys.dm_db_index_physical_stats (DB_ID(),NULL,NULL,NULL,NULL) p;	--server level, статистика по состоянию индекса (фрагментация, сжатие, уровни, кол-во строк и пр.)
select * from sys.dm_db_partition_stats;										--DB level, статистика по партициям (кол-во страниц, сжатие и пр.)

select * from sys.dm_db_fts_index_physical_stats;


/*index size and fragmentation statistics
последний параметр - уровень детализации: NULL/LIMITED -> SAMPLED -> DETAILED*/
select * from sys.dm_db_index_physical_stats(db_id(),OBJECT_ID('TMP_PORTFOLIO_ERM_CCY'),NULL,NULL,NULL);
select * from sys.dm_db_index_physical_stats(db_id(),OBJECT_ID('TMP_PORTFOLIO_ERM_CCY'),NULL,NULL,'SAMPLED');
select * from sys.dm_db_index_physical_stats(db_id(),OBJECT_ID('TMP_PORTFOLIO_ERM_CCY'),NULL,NULL,'DETAILED');

----------------------------------------
/*текущее физическое состояние индекса*/
----------------------------------------
select t.object_id obj_id, t.name tbl_nm, SCHEMA_NAME(t.schema_id) shm_nm, t.type_desc
, i.index_id idx_id, i.name idx_nm, i.type_desc, i.fill_factor
, p.partition_number, p.alloc_unit_type_desc, p.index_depth
, p.avg_fragmentation_in_percent, p.fragment_count, p.page_count, p.record_count
, p.avg_page_space_used_in_percent, p.compressed_page_count
from sys.tables t
left join sys.indexes i
	on i.object_id = t.object_id
left join sys.dm_db_index_physical_stats (db_id(),NULL,NULL,NULL,'DETAILED') p
	on p.object_id = t.object_id
	and p.index_id = i.index_id
where t.is_ms_shipped = 0 
and i.index_id >= 1
and p.index_level = 0 --только листовой уровень
order by obj_id, idx_id;

/* 
partition_number - номер партиции внутри объекта: табоицы, представления или индекса. 1 - несекционированный индекс или куча
index_depth - кол-во уровней индекса
index_level - текущий уровень индекса, 0 - конечный уровень, наибольшее значение - корневой уровень
avg_fragmentation_in_percent - уровень фрагментации индекса(логическая фрагменитация)/кучи(фрагментация экстентов) (внешняя фрагментация) (чем ниже тем лучше, 0-20)
fragment_count - число фрагментов на уровне листьев (физич. последовательные страницы в индексе)
	Логич. фрагментация - процент неупорядоченных страниц конечного уровня индекса
	Фрагментация влияет на упреждающее чтение
avg_fragment_size_in_pages - среднее число страниц в одном фрагменте индекса на уровне листьев (чем выше тем лучше)
	avg_fragment_size_in_pages = pages / fragment_count
page_count - общее кол-во страниц индекса или данных на текущем уровня B-tree
avg_page_space_used_in_percent - отражает заполненность страниц, исп. всеми страницами (чем выше тем лучше, 90-100)
record_count - общее кол-во записей на листьях
ghost_record_count  - кол-во фантомных записей

если avg_fragmentation_in_percent < 30  => REORGANIZE 
если avg_fragmentation_in_percent > 30  => REBUILD */



------------------------------------------------------
/*статистика использования индекса на уровне страниц*/
------------------------------------------------------
select * from sys.dm_db_index_operational_stats (DB_ID(),object_id('Contracts'),NULL,NULL) o;	
select * from sys.dm_db_index_usage_stats where object_id = 2130106629

use <DB>

select db_name(i.database_id) db_nm
	, object_name(i.object_id) obj_nm
	, i.index_id idx_id
	, i.partition_number prtn_nmb
	, i.range_scan_count scn_cnt		--read. Cumulative count of range and table scans
	, i.singleton_lookup_count sek_cnt	--read. Cumulative count of single row retrievals from the index or heap
--	, i.forwarded_fetch_count			--Count of rows that were fetched through a forwarding record
	, i.leaf_insert_count leaf_ins_cnt	--write
	, i.leaf_update_count leaf_upd_cnt	--write
	, i.leaf_delete_count leaf_del_cnt 	--write
	, i.leaf_ghost_count leaf_ghst_cnt
--	, i.leaf_page_merge_count leaf_mrg_cnt
	, i.page_io_latch_wait_count pg_io_latсh_cnt
	, i.page_io_latch_wait_in_ms pg_io_latсh_ms
	, iif(i.page_io_latch_wait_count=0, 0, i.page_io_latch_wait_in_ms/i.page_io_latch_wait_count) avg_pg_io_latсh_ms
from sys.dm_db_index_operational_stats (null,null,null,null) i
where OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
and (i.leaf_insert_count + i.leaf_update_count + i. leaf_delete_count + i.leaf_ghost_count + i.leaf_page_merge_count + i.range_scan_count + i.singleton_lookup_count) != 0
and i.database_id = db_id()
--and i.object_id = 2130106629
--order by i.singleton_lookup_count desc
--order by i.range_scan_count desc
order by avg_pg_io_latсh_ms desc
	
			--агрегированные данные: read/write
			select db_name(i.database_id) db_nm
				, object_name(i.object_id) obj_nm
				, i.index_id idx_id
				, i.partition_number prtn_nmb
				, (i.range_scan_count + i.singleton_lookup_count) 'Reads'
				, (i.leaf_insert_count + i.leaf_update_count + i.leaf_delete_count + i.leaf_ghost_count) 'Writes'
				, i.page_io_latch_wait_count pg_io_latсh_cnt
				, i.page_io_latch_wait_in_ms pg_io_latсh_ms
				, iif(i.page_io_latch_wait_count=0, 0, i.page_io_latch_wait_in_ms/i.page_io_latch_wait_count) avg_pg_io_latсh_ms
			from sys.dm_db_index_operational_stats (null,null,null,null) i
			where (i.leaf_insert_count + i.leaf_update_count + i. leaf_delete_count + i.leaf_ghost_count + i.leaf_page_merge_count + i.range_scan_count + i.singleton_lookup_count) != 0
			and (i.leaf_insert_count + i.leaf_update_count + i. leaf_delete_count + i.leaf_ghost_count + i.leaf_page_merge_count) = 0
			and i.database_id = db_id()
			and OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
			order by i.range_scan_count + i.singleton_lookup_count desc


-------------------------------------------------------
/*статистика использования индекса на уровне запросов*/
-------------------------------------------------------
/*
Seeks indicates the number of times the index is used to find a specific row
Scans shows the number of times the leaf pages of the index are scanned 
Lookups indicates the number of times a Clustered index is used by the Non-clustered index to fetch the full row 
Updates shows the number of times the index data is modified
*/
use <DB>

/*весь экземпляр*/
select db_name(u.database_id) db_nm, u.object_id obj_id, OBJECT_NAME(u.object_id) obj_nm, u.index_id idx_id, 
u.user_seeks, u.user_scans, u.user_lookups, u.user_updates,
u.system_seeks, u.system_scans, u.system_lookups, u.system_updates
from sys.dm_db_index_usage_stats u
where u.database_id = db_id() --current DB
and (u.user_seeks + u.user_scans + u.user_lookups + u.user_updates) <> 0
--and u.index_id = 0
order by u.user_scans desc


			--только пользовательские операции, без системных!!!
			select t.object_id obj_id, t.name tbl_nm, SCHEMA_NAME(t.schema_id) shm_nm, t.type_desc
			, i.index_id idx_id, i.name idx_nm, i.type_desc
			, u.user_seeks, u.user_scans, u.user_lookups, u.user_updates
			, u.system_seeks, u.system_scans, u.system_lookups, u.system_updates
			from sys.tables t
			left join sys.indexes i
				on i.object_id = t.object_id
			left join sys.dm_db_index_usage_stats u
				on u.database_id = db_id()
				and u.object_id = t.object_id
				and u.index_id = i.index_id 
			where t.is_ms_shipped = 0 
			--and i.index_id >= 1
			and u.database_id is not null
			--and u.user_seeks > 0
			--and i.index_id = 0
			--and i.object_id = 2130106629
			order by u.user_scans desc




			SELECT OBJECT_NAME(IX.OBJECT_ID) Table_Name
			,IX.name AS Index_Name
			,IX.type_desc Index_Type
			,SUM(PS.[used_page_count]) * 8 IndexSizeKB
			,IXUS.user_seeks AS NumOfSeeks
			,IXUS.user_scans AS NumOfScans
			,IXUS.user_lookups AS NumOfLookups
			,IXUS.user_updates AS NumOfUpdates
			,IXUS.last_user_seek AS LastSeek
			,IXUS.last_user_scan AS LastScan
			,IXUS.last_user_lookup AS LastLookup
			,IXUS.last_user_update AS LastUpdate
			FROM sys.indexes IX
			INNER JOIN sys.dm_db_index_usage_stats IXUS ON IXUS.index_id = IX.index_id AND IXUS.OBJECT_ID = IX.OBJECT_ID
			INNER JOIN sys.dm_db_partition_stats PS on PS.object_id=IX.object_id
			WHERE OBJECTPROPERTY(IX.OBJECT_ID,'IsUserTable') = 1
			GROUP BY OBJECT_NAME(IX.OBJECT_ID) ,IX.name ,IX.type_desc ,IXUS.user_seeks ,IXUS.user_scans ,IXUS.user_lookups,IXUS.user_updates ,IXUS.last_user_seek ,IXUS.last_user_scan ,IXUS.last_user_lookup ,IXUS.last_user_update



/*The previous result can be analyzed as follows:

All zero values mean that the table is not used, or the SQL Server service restarted recently.
An index with zero or small number of seeks, scans or lookups and large number of updates is a useless index and should be removed, after verifying with the system owner, as the main purpose of adding the index is speeding up the read operations.
An index that is scanned heavily with zero or small number of seeks means that the index is badly used and should be replaced with more optimal one.
An index with large number of Lookups means that we need to optimize the index by adding the frequently looked up columns to the existing index non-key columns using the INCLUDE clause.
A table with a very large number of Scans indicates that SELECT * queries are heavily used, retrieving more columns than what is required, or the index statistics should be updated.
A Clustered index with large number of Scans means that a new Non-clustered index should be created to cover a non-covered query.
Dates with NULL values mean that this action has not occurred yet.
Large scans are OK in small tables.
Your index is not here, then no action is performed on that index yet.*/





-------------------
/*missing indexes*/
-------------------
use <DB>

select * from sys.dm_db_missing_index_details
select * from sys.dm_db_missing_index_columns()
select * from sys.dm_db_missing_index_groups
select * from sys.dm_db_missing_index_group_stats


--при создании индекса на основе DMV sys.dm_db_missing_... нужно перепроверить эти DMV, могут пропасть дуругие индексы
select db_name(d.database_id) db_nm, d.statement tbl_nm
, g.user_seeks, g.user_scans, g.avg_total_user_cost, g.avg_user_impact
, object_name(d.object_id) obj_nm
, d.equality_columns --столбцы для условия =
, d.inequality_columns --столбцы для условия >, <
, d.included_columns --включенные столбцы
        
,g.[user_seeks] * g.[avg_total_user_cost] * (g.[avg_user_impact] * 0.01) AS [IndexAdvantage]

from sys.dm_db_missing_index_group_stats g
left join sys.dm_db_missing_index_groups f
	on g.group_handle = f.index_group_handle
left join sys.dm_db_missing_index_details d
	on f.index_handle = d.index_handle
where 1=1
and db_name(d.database_id) != 'tempdb' 
--and object_name(d.object_id) = 'crcard_tmp_'
--and g.avg_user_impact > 90
--and d.object_id in (select object_id from sys.indexes where index_id != 1 group by object_id having count(*) = 1) --ищем только кучи без NCI  в текущей БД
--order by user_seeks + user_scans desc
ORDER BY [IndexAdvantage] desc
order by (g.user_seeks+g.user_scans)*g.avg_total_user_cost*avg_user_impact desc
--order by avg_total_user_cost desc


			select db_name(d.database_id) db_nm, d.statement tbl_nm
			, d.equality_columns --столбцы для условия =
			, d.inequality_columns --столбцы для условия >, <
			, count(*) cnt
			from sys.dm_db_missing_index_group_stats g
			left join sys.dm_db_missing_index_groups f
				on g.group_handle = f.index_group_handle
			left join sys.dm_db_missing_index_details d
				on f.index_handle = d.index_handle
			where db_name(d.database_id) != 'tempdb' 
			--and d.included_columns is null
			--and d.object_id in (select object_id from sys.indexes where index_id != 1 group by object_id having count(*) = 1) --ищем только кучи без NCI  в текущей БД
			group by db_name(d.database_id), d.statement, d.equality_columns, d.inequality_columns
			order by cnt desc
			--order by 2,3,4


			select d.statement tbl_nm, 
			g.user_seeks, g.last_user_seek, g.user_scans, g.last_user_scan, g.avg_total_user_cost, g.avg_user_impact,
			d.equality_columns, d.inequality_columns
			from sys.dm_db_missing_index_group_stats g
			left join sys.dm_db_missing_index_groups f
				on g.group_handle = f.index_group_handle
			left join sys.dm_db_missing_index_details d
				on f.index_handle = d.index_handle
			where db_name(d.database_id) != 'tempdb' 
			d.statement = '[dbo].[pers_info]'



			;  with cte as (
				select d.statement tbl_nm, 
				sum(g.user_seeks) usr_seks, sum(g.user_scans) usr_scns, sum(g.user_seeks) + sum(g.user_scans) usr_oper, sum(g.avg_user_impact*(g.user_seeks+g.user_scans))/sum(g.user_seeks+g.user_scans) influence,
				d.equality_columns, len(d.equality_columns) - len (replace(d.equality_columns,',','')) eq_col_cnt,
				d.inequality_columns, len(d.inequality_columns) - len (replace(d.inequality_columns,',','')) ineq_col_cnt
				from sys.dm_db_missing_index_group_stats g
				left join sys.dm_db_missing_index_groups f
					on g.group_handle = f.index_group_handle
				left join sys.dm_db_missing_index_details d
					on f.index_handle = d.index_handle
				--where d.statement = '[SMP].[dbo].[pers_info]'
				group by d.statement, d.equality_columns, d.inequality_columns
				),
				cte1 as (
					select *, CHARINDEX(equality_columns,',',0)
					from cte		
				)
				










			)
			select db_name(d.database_id) db_nm, d.statement tbl_nm
			, g.user_seeks, g.user_scans, g.avg_total_user_cost, g.avg_user_impact
			, object_name(d.object_id) obj_nm
			, d.equality_columns --столбцы для условия =
			, d.inequality_columns --столбцы для условия >, <
			, d.included_columns --включенные столбцы
			from sys.dm_db_missing_index_group_stats g
			left join sys.dm_db_missing_index_groups f
				on g.group_handle = f.index_group_handle
			left join sys.dm_db_missing_index_details d
				on f.index_handle = d.index_handle
			where 1=1
			and db_name(d.database_id) != 'tempdb' 
			and g.avg_user_impact > 90
			and d.object_id in (select object_id from sys.indexes where index_id != 1 group by object_id having count(*) = 1)
			--order by user_seeks desc
			order by avg_total_user_cost desc














/*	monitoring indexes	*/
set nocount on;
begin 
	declare @server nvarchar(32);			/* the server name */
	declare @db nvarchar(32);				/* the database name*/
	declare @date_a datetime;				/* period of 3 day */
	declare @date_b datetime;				/* current date */

	select @server = @@servername;
	select @db = db_name();
	select @date_a = cast(convert(char(8), getdate() - 3, 112) as datetime); 
	select @date_b = cast(convert(char(8), getdate(), 112) as datetime);	

	--select db_name();
	if object_id('dbo.TAB_INDEX_SPACE') is null		/* create the table if not exists */
		create table dbo.TAB_INDEX_SPACE (
			date_scan datetime	
			,database_name nvarchar(64)
			,schema_name nvarchar(32)
			,table_name	nvarchar(128)
			,index_name	nvarchar(128)
			,index_type_desc nvarchar(64)
			,avg_fragmentation_in_percent int
			,recomended_for_informational_purposes_only	nvarchar(256)
	); 

	begin
		declare @index_fr table (				/* create the table varible for interediate resutls */ 
			date_scan datetime
			,database_name nvarchar(64)
			,object_id int
			,index_id int
			,index_type_desc nvarchar(30)
			,avg_fragmentation_in_percent int
		);
		
		/*      debug                                            */
		--select @date_scan = dateadd("month", -1, @date_scan)
		--select @date_b = dateadd("day", -1, @date_b)  
		
		insert into @index_fr select
			@date_b
			,@db    
			,object_id
			,index_id
			,index_type_desc
			,avg_fragmentation_in_percent
			from sys.dm_db_index_physical_stats(db_id(@db), null, null , null, 'limited') 	
				where index_id > 0 and avg_fragmentation_in_percent > 10; 

		insert into dbo.TAB_INDEX_SPACE select
			date_scan
			,database_name
			,sc.name as [schema_name] 
			,o.name as [table_name]
			,s.name as [index_name]
			,index_type_desc
			,avg_fragmentation_in_percent
			,'recomended_for_informational_purposes_only' = case 
				when avg_fragmentation_in_percent < 30 
					and  s.name not in (select distinct name from sys.indexes with(nolock) where (allow_page_locks = 0 or type = 1))
					then 'alter index ' + quotename(s.name) + ' on '+ quotename(sc.name) +'.'+ quotename(o.name) +' reorganize;'
				when avg_fragmentation_in_percent > 30 
					and o.object_id not in (select distinct object_id from sys.columns with(nolock) where system_type_id in (34,35,99,167,231,165,241)) 
				then 'alter index ' + quotename(s.name) + ' on '+ quotename(sc.name) +'.'+ quotename(o.name) +' rebuild with (online = on, maxdop = 8)'
				  else 'alter index ' + quotename(s.name) + ' on '+ quotename(sc.name) +'.'+ quotename(o.name) +' rebuild with (online = off, maxdop = 8)'
				end	
			from @index_fr as ifr
				inner join sys.objects as o with(nolock) on ifr.object_id = o.object_id
				inner join sys.schemas as sc with(nolock) on sc.schema_id = o.schema_id
				inner join sys.indexes as s with(nolock) on ifr.object_id = s.object_id and ifr.index_id = s.index_id;
	end
	begin
		--use monitoring;
		--go
		declare @error nvarchar(256);  /* write error to the errorlog */
		declare @count_a int;		   /* */
		declare @count_b int;		   /* */

		select @error = N'Warning: 50005, Severity: 10, State: 1. SQL Server instance '+ @server +' Indexes fragmentation in the database '+ @db +' exceeds 50 percent.';

		select @count_a = count(date_scan) from dbo.TAB_INDEX_SPACE 
			where date_scan between @date_a and @date_b and avg_fragmentation_in_percent > 50;
	 
		select @count_b = count(date_scan)/2 from dbo.TAB_INDEX_SPACE 
			where date_scan between @date_a and @date_b;

		if @count_a > @count_b raiserror(@error , 10, 1) with log;

		delete from dbo.TAB_INDEX_SPACE where database_name = db_name() and date_scan < dateadd(Month, -1, GetDate());
		/* debug */
		select * from dbo.TAB_INDEX_SPACE;
		drop table dbo.TAB_INDEX_SPACE
	end
end



--------------------------------------------------------------------------------------------
-----------------------------------------Detail info----------------------------------------
--------------------------------------------------------------------------------------------


/*детальная информация по структуре индекса*/

--вариант 1 (через DBCC)
	DBCC TRACEON(3604) -- вывод данных в консоль, а не в лог
	GO
	/*параметры: имя БД, имя таблицы, id индекса*/
	DBCC IND('KP', 'fok_id', 1)
	go
	DBCC TRACEOFF

	/*3.2. все старницы для конкретного индекса*/
	create table #tab
	(
		PageFID tinyint
		, PagePID int
		, IAMFID tinyint
		, IAMPID int
		, ObjectID int
		, IndexID tinyint
		, PartitionNumber tinyint
		, PartitionID bigint
		, IAM_chain_type varchar(30)
		, Page_type tinyint
		, IndexLevel tinyint
		, NextPageFID int
		, NextPagePID int
		, PrevPageFID int
		, PrevPagePID int
		)

	insert into #tab exec ('DBCC IND (KP, fok_id, 1)')
	select * from #tab order by Page_type desc, IAM_chain_type, indexlevel desc
	truncate table #tab
	
	/*4. детальная информация по страницам индекса:  <имя БД>, <номер файла>, <номер страницы>, опция для вывода [1,2,3]*/
		DBCC TRACEON(3604) -- вывод данных в консоль, а не в лог
		GO
		DBCC PAGE(KP,1,20392408,3)
		go
		DBCC TRACEOFF
		go



--вариант 2 (через DMF)
	/*первая строка - IAM-page (page type = 10)
	page level = n,n-1,...,2,1 - корневой и промежуточные уровни индекса (page type = 2)
	page level = 0 - листовой уровень индекса (page type = 2, 1 - в зависимости от типа индекса)
	для условия is_allocated = 1 кол-во строк должно совпадать с запросом DBCC IND
	тут также указаны страницы для экстентов, которые принадлежат объекту: для экстента extent_page_id будет совпадать*/
	select * from sys.dm_db_database_page_allocations(DB_ID('TEST'),object_id('dbo.Books'), NULL, NULL, 'DETAILED')
	where index_id = 1 --index_id, можно задать и в параметре функции
	and is_allocated = 1 --страница размещена
	order by index_id, is_iam_page desc, is_allocated desc, page_level desc, allocated_page_page_id


------------------------------------------------------------------------------------------------------------------------------------------
--интересное наблюдение Unique/Nonunique Index


drop table if exists tmp;
create table tmp (id int not null identity(1000,1), num int not null, val char(50) not null);

	create table tmp (id int not null identity(1000,1) primary key, num int not null, val char(50) not null);


--заполняем таблицу
; with cte as (select * from (values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) t(num))
, cte1 as (
	select 
	t6.num * 100000 +
	t5.num * 10000 +
	t4.num * 1000 +
	t3.num * 100 +
	t2.num * 10 +
	t1.num + 1 num
	, 'aaa' val
	from cte t1
	cross join cte t2
	cross join cte t3
	cross join cte t4
	cross join cte t5
	cross join cte t6)
insert into tmp (num,val)
	select num, val from cte1
	order by num	--сортировка не дает упорядоченную вставку, разница в производительности на уровне погрешности


select top (10) * from tmp;
select count(*) from tmp;
EXEC sp_spaceused N'dbo.tmp', @updateusage = N'TRUE'

/*Видимо различие в размере между UCI и NuCI на уровне погрешности
Нужно проверять другие типы данных и объемы таблиц*/

--dbo.tmp	1000000             	80840 KB	80816 KB	8 KB	16 KB	heap
--dbo.tmp	1000000             	67016 KB	66680 KB	144 KB	192 KB	NuCI
--dbo.tmp	1000000             	67080 KB	66680 KB	144 KB	256 KB	UCI
--dbo.tmp	1000000             	66824 KB	66680 KB	8 KB	136 KB	heap (drop CI)

--dbo.tmp	1000000             	81160 KB	80816 KB	312 KB	32 KB	CI (PK)
--dbo.tmp	1000000             	67080 KB	66680 KB	144 KB	256 KB	CI (PK rebuild)

--create Nonunique CI
drop index if exists CI_tmp on tmp
create clustered index CI_tmp on tmp (id)

			--проверка
			select * from sys.dm_db_database_page_allocations(DB_ID('master'),object_id('dbo.tmp'), NULL, NULL, 'DETAILED')
			where index_id = 1 --index_id, можно задать и в параметре функции
			and is_allocated = 1 --страница размещена
			order by index_id, is_iam_page desc, is_allocated desc, page_level desc, previous_page_page_id

			DBCC TRACEON(3604) -- вывод данных в консоль, а не в лог
			DBCC PAGE(master,1,49712,3)
			DBCC TRACEOFF

40938
40936

--create unique CI
drop index if exists CI_tmp on tmp
create unique clustered index CI_tmp on tmp (id)

49714
49680

alter table tmp rebuild 

--create Nonunique NCI
drop index if exists NuNC_temp on tmp
create nonclustered index NuNC_temp on tmp(num)

drop index if exists UNC_temp on tmp
create unique nonclustered index UNC_temp on tmp(num)

			--проверка
			select * from sys.dm_db_database_page_allocations(DB_ID('master'),object_id('dbo.tmp'), NULL, NULL, 'DETAILED')
			where index_id = 2 --index_id, можно задать и в параметре функции
			and is_allocated = 1 --страница размещена
			order by index_id, is_iam_page desc, is_allocated desc, page_level desc, previous_page_page_id

			DBCC TRACEON(3604) -- вывод данных в консоль, а не в лог
			DBCC PAGE(master,1,136208,3)
			DBCC TRACEOFF

127538
127536

136210
136208
136144

EXEC sp_spaceused N'dbo.tmp', @updateusage = N'TRUE'
select * from sys.dm_db_index_physical_stats(db_id(),OBJECT_ID('dbo.tmp'),null,NULL,'DETAILED');

name	rows	reserved	data	index_size	unused
dbo.tmp	1000000             	131920 KB	66688 KB	64624 KB	608 KB
dbo.tmp	1000000             	131408 KB	66680 KB	64192 KB	536 KB


drop index if exists CI_tmp on tmp
create unique clustered index CI_tmp on tmp (id,val)



