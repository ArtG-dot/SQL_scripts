--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------
/*объект хранящий данные: таблица, CI, NCI состояит из partition (секций)
каждая секция имеет свой тип allocation unit (распределенного пространства): IN_ROW_DATA, ROW_OVERFLOW_DATA, LOB_DATA
*/

/*список всех пользовательских(!) таблиц в БД*/
select * from sys.tables
select * from sys.columns
select * from sys.indexes

/*список всех partitions в БД
для каждой таблицы существует минимум 1 partition (сама таблица) + партиции для индексов
index_id = 0 (heap), = 1 (clust. index), >=2 (nonclust. index)*/
select * from sys.partitions
/*подробная информация о всех partitions в текущей БД*/
select * from sys.dm_db_partition_stats

/*на уровне страниц и экстентов*/
select * from sys.dm_db_database_page_allocations(DB_ID('TEST'),object_id('dbo.Books'), NULL, NULL, 'DETAILED')

/*список всех allocation_units для partitions
типы:IN_ROW_DATA (HoBT), ROW_OVERFLOW_DATA (Small-LOB, SLOB), LOB_DATA (LOB)
для каждой partition существует от 1 до 3 allocation_unit разного типа в зависимости от полей таблицы*/
select * from sys.allocation_units

select * from sys.all_objects
where type = 'U'

/*Displays the number of rows, disk space reserved, and disk space used by a table, indexed view, 
or Service Broker queue in the current database, or displays the disk space reserved and used by the whole database.
*/
exec sp_spaceused 'Books'
			
			--данные могут быть неточными, поэтому можно добавить параметр @updateusage
			EXEC sp_spaceused N'dbo.Books', @updateusage = N'TRUE'; --запуск операции DBCC UPDATEUSAGE для данного объекта



/*инфо для конкретной пользовательской таблицы*/
select t.name table_name
, t.type_desc
, t.create_date
, p.index_id --  = 0 (heap), =1 (clust. index), >=2 (nonclust. index) 
, p.partition_number
, f.name file_group
, p.rows --приблизительное кол-во строк
, p.data_compression_desc
, a.type_desc
, a.data_pages
, case when a.data_pages*8/1024/1024 = 0 then 'less then 1' else cast(a.data_pages*8/1024/1024 as varchar(10)) end data_GB --данные
, a.used_pages
, case when a.used_pages*8/1024/1024 = 0 then 'less then 1' else cast(a.used_pages*8/1024/1024 as varchar(10)) end used_GB --данные + метаданные (IAM и пр)
, a.total_pages
, case when a.total_pages*8/1024/1024 = 0 then 'less then 1' else cast(a.total_pages*8/1024/1024 as varchar(10)) end total_GB --зарезервировано
, p.data_compression_desc
--, t.*
--, p.*
--, a.*
--, ps.*
from sys.tables t
left join sys.partitions p
	on t.object_id = p.object_id
left join sys.allocation_units a
	on a.container_id = case
							when a.type in (1,3) then p.hobt_id
							when a.type = 2 then p.partition_id
						end
left join sys.dm_db_partition_stats ps
	on ps.partition_id = p.partition_id
left join sys.filegroups f
	on f.data_space_id = a.data_space_id
where p.index_id in (1) 
--and t.object_id in(OBJECT_ID('param_info_cut_20180503')
--,OBJECT_ID('param_info_SpecCond_2018_12_25')
--,OBJECT_ID('auto_20180713')
--,OBJECT_ID('auto_german_20180910')
--)
--and p.data_compression_desc != 'NONE'
order by data_pages desc--p.partition_number
