 /*в memory хранятся все необходимы кеши сервера (Data Cache, Plan Cache и др.)
 */
 
 select * from sys.dm_os_memory_clerks order by virtual_memory_reserved_kb desc



 --------------
 /*Data Cache*/
 --------------
 /*буфферный пул (в данном случае Data Cache) - это выделенное пространство в памяти, для хранения кешированных страниц
грязные страницы (dirty pages) - это страницы в буфферном пуле которые были изменены (т.е. эта страница отличается от той, которая лежит на диске)
checkpoint 
  */ 
 
/*информация о буффер пул (Data Cache): каждая строка это закешированная страница хранящаяся в buffer pool
is_modified - флаг для грязных страниц
*/


select * from sys.dm_os_buffer_descriptors

/*список БД, и размер страницы которых хранятся в buffer pool*/
select db_name(database_id) db_nm, count(*)/1024*8192/1024 'MB', 
count(*)*100/(select count(*) from sys.dm_os_buffer_descriptors) [%]
from sys.dm_os_buffer_descriptors
group by db_name(database_id)
order by 2 desc, 3 desc

			select object_name(p.object_id) tbl_nm, count(*)/1024*8192/1024 'MB'
			from sys.dm_os_buffer_descriptors b
			join sys.allocation_units u 
				on b.allocation_unit_id = u.allocation_unit_id
			join sys.partitions p
				on p.partition_id = u.container_id
			join sys.tables t
				on t.object_id = p.object_id
			where b.database_id = db_id()
				and t.is_ms_shipped = 0
			group by p.object_id
			having count(*)/1024*8192/1024 > 0
			order by 2 desc



/*clean buffer pool*/
--можно исп. для проверки запроса на "холодном" (пустом) буфферном пуле без перезапуска сервера

--1. выполняем сброс грязных страниц из памяти (буфферный кеш) на диск, чистим буфферы  ТОЛЬКО ДЛЯ ТЕКУЩЕЙ БД (!!!)
CHECKPOINT --создание контрольной точки вручную (в БД к которой подключена сессия)
  
--2. удаление буфферов из buffer pool (ДЛЯ ВСЕГО СЕРВЕРА)
DBCC DROPCLEANBUFFERS --Removes all clean buffers from the BUFFER POOL, and columnstore objects from the columnstore object pool.
	DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS --подавляет вывод информ. сообщений
















--	????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
SELECT
indexes.name AS index_name,
objects.name AS object_name,
objects.type_desc AS object_type_description,
COUNT(*) AS buffer_cache_pages,
COUNT(*) * 8 / 1024  AS buffer_cache_used_MB
FROM sys.dm_os_buffer_descriptors
INNER JOIN sys.allocation_units
ON allocation_units.allocation_unit_id = dm_os_buffer_descriptors.allocation_unit_id
INNER JOIN sys.partitions
ON ((allocation_units.container_id = partitions.hobt_id AND type IN (1,3))
OR (allocation_units.container_id = partitions.partition_id AND type IN (2)))
INNER JOIN sys.objects
ON partitions.object_id = objects.object_id
INNER JOIN sys.indexes
ON objects.object_id = indexes.object_id
AND partitions.index_id = indexes.index_id
WHERE allocation_units.type IN (1,2,3)
AND objects.is_ms_shipped = 0
AND dm_os_buffer_descriptors.database_id = DB_ID()
GROUP BY indexes.name,
objects.name,
objects.type_desc
ORDER BY COUNT(*) DESC;







SELECT (CASE 
           WHEN ( [database_id] = 32767 ) THEN 'Resource Database' 
           ELSE Db_name (database_id) 
         END )  AS 'Database Name', 
       Sum(CASE 
             WHEN ( [is_modified] = 1 ) THEN 0 
             ELSE 1 
           END) AS 'Clean Page Count',
		Sum(CASE 
             WHEN ( [is_modified] = 1 ) THEN 1 
             ELSE 0 
           END) AS 'Dirty Page Count'
FROM   sys.dm_os_buffer_descriptors 
GROUP  BY database_id 
ORDER  BY DB_NAME(database_id);




SELECT db_name(database_id) AS 'Database',count(page_id) AS 'Dirty Pages'
FROM sys.dm_os_buffer_descriptors
WHERE is_modified =1
GROUP BY db_name(database_id)
ORDER BY count(page_id) DESC





























;WITH s_obj as (
    SELECT
        OBJECT_NAME(OBJECT_ID) AS name, index_id ,allocation_unit_id, OBJECT_ID
    FROM sys.allocation_units AS au
    INNER JOIN sys.partitions AS p
    ON au.container_id = p.hobt_id
    AND (au.type = 1 
        OR au.type = 3)
    UNION ALL
    SELECT OBJECT_NAME(OBJECT_ID) AS name, index_id, allocation_unit_id, OBJECT_ID
    FROM sys.allocation_units AS au
    INNER JOIN sys.partitions AS p
    ON au.container_id = p.partition_id
    AND au.type = 2
    ),
obj as (
    SELECT
        s_obj.name, s_obj.index_id, s_obj.allocation_unit_id, s_obj.OBJECT_ID, i.name IndexName, i.type_desc IndexTypeDesc
    FROM s_obj
    INNER JOIN sys.indexes i 
    ON i.index_id = s_obj.index_id
    AND i.OBJECT_ID = s_obj.OBJECT_ID
    )
SELECT
    COUNT(*) AS cached_pages_count, obj.name AS BaseTableName, IndexName, IndexTypeDesc
FROM sys.dm_os_buffer_descriptors AS bd
INNER JOIN obj
ON bd.allocation_unit_id = obj.allocation_unit_id
INNER JOIN sys.tables t
ON t.object_id = obj.OBJECT_ID
WHERE database_id = DB_ID()
--AND obj.name = 'Person'
--AND schema_name(t.schema_id) = 'dbo'
GROUP BY obj.name, index_id, IndexName, IndexTypeDesc
ORDER BY cached_pages_count DESC;


