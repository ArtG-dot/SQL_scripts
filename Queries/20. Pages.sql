--------------------------------------------------------------------------------------------
-------------------------------------------Records------------------------------------------
--------------------------------------------------------------------------------------------

/*record is the physical storage associated with table or index row
record types:
data records
forwarding records
index records
Leaf level index records
Non-leaf level index records
text records
ghost records
other record types

record structure:
1. record header (4 bytes) = 2 bytes for metadata + 2 bytes pointing forward to the null bitmap
2. fixed length portion of record
3. null bitmap
4. variable-length column offset array
4. versioning tag
*/

--------------------------------------------------------------------------------------------
--------------------------------------------Pages-------------------------------------------
--------------------------------------------------------------------------------------------

/*
Page size: 8KB = 8192 bytes = 96 bytes (header) + 8060 bytes (data) + (rowoffset array)

Page type:
1. Data page 	- хранит данные
2. Index page	- записи некласт индекса листового уровня и нелистового уровня класт и некласт индексов
3. Text mixed page - for LOB
4. Text tree page - for LOB
6. WF page (Work file page)
7. Sort page
8. GAM	- global allocation map (1 - экстент доступен для распределения, свободен; 0 - экстент распределен) (принцип одинаков для uniform и mixed extents)
9. SGAM - shared global allocayion map (1 - экстент смешанный и имеет хотя бы 1 свободную страницу, 0 - uniform extent или mixed extend без свободных страниц)
10. IAM	- index allocation map - для каждого allocation unit каждого типа
11. PFS	- page free space - информация о распределении свободного места на страницах
13. Boot page
15. File header page
16. Diff map page (Diff = differential) - These pages track which extents have been modified since the last full backup was taken. It is a common misconception that the bitmaps track the changes since the last differential backup.
17. ML map page (ML = Minimally Logged) - These pages track which extents have been modified by minimally-logged operations since the last ion log backup when using the BULK_LOGGED recovery model. If you don't ever use the BULK_LOGGED recovery model, these pages are never used.
18. page for CHECKDB operation 
19. Temp page
20. pre-alloc page

GAM, SGAM, IAM => 8000 (bytes on page) * 8 (bits in byte) * 8 (1 extent = 8 pages) * 8 kb (page size)  = 4GB of data или 511230 pages (если файл/объект больше, то создаются новые GAM, SGAM, IAM страницы)
Файл данных БД делится (не физически, а концептуально) на GAM-интервалы (интервал равен примерно 4GB = 64000 extents = 64000 * 8 pages)
GAM-интервал одинаков для GAM, SGAM, IAM, ML map и DIFF map (все эти типы страниц хранят битовые маски, т.е. bit-map). 
1 bit на этих страницах отвечает (соответствует) 1 extent, но имеет разное значение.

в начале каждого GAM-интервала есть GAM-extent, который содержит global allocation pages для этого GAM-интервала.
Структура GAM-extent:
Page 0: the file header page
Page 1: the first PFS page
Page 2: the first GAM page
Page 3: the first SGAM page
Page 4: Unused in 2005+
Page 5: Unused in 2005+
Page 6: the first DIFF map page
Page 7: the first ML map page

GAM (одинаково для mixed/uniform extent): 
bit = 1: the extent is available for allocation 
bit = 0: the extent is already allocated for use 

SGAM:
bit = 1: the extent is a mixed extent and may have at least one unallocated page available for use (it's an optimistic update algorithm)
bit = 0: the extent is either uniform or is a mixed extent with no unallocated pages (essentially the same situation given that the SGAM is used to find mixed extents with unallocated pages)

IAM:
bit = 1: the extent is allocated to the IAM chain/allocation unit
bit = 0: the extent is not allocated to the IAM chain/allocation unit

GAM	SGAM IAM	
0	0	 0	  Mixed extent, все страницы распределены (Mixed extent with all pages allocated)
0	0	 1	  Uniform extent, дб распределен только одной страницей IAM (Uniform extent (must be allocated to only a single IAM page))
0	1	 0	  Mixed extent, хотя бы 1 свободная страница (Mixed extent with >= 1 unallocated page)
0	1	 1	  недопустимо (Invalid state)
1	0	 0	  Свободный экстент (Unallocated extent)
1	0	 1	  недопустимо (Invalid state)
1	1	 0	  недопустимо (Invalid state)
1 	1	 1	  недопустимо (Invalid state)

ML map page:
bit = 1: the extent has been changed by a minimally logged operation since the last ion log backup
bit = 0: the extent was not changed

DIFF map pages:
bit = 1: the extent has been changed since the last full backup
bit = 0: the extent was not changed

По аналогии с GAM-интервалами, каждый файл БД делится на PFS-интервалы (8088 pages = 64 MB).
однако PFS-страница это не bit-map, а byte-map. По 1 byte для каждой страницы.
The bits in each byte are encoded to mean the following:
bits 0-2: how much free space is on the page
	0x00 is empty
	0x01 is 1 to 50% full
	0x02 is 51 to 80% full
	0x03 is 81 to 95% full
	0x04 is 96 to 100% full
bit 3 (0x08): is there one or more ghost records on the page?
bit 4 (0x10): is the page an IAM page?
bit 5 (0x20): is the page a mixed-page?
bit 6 (0x40): is the page allocated?
Bit 7 is unused
*/


/*
при вставке/изменении данных если данные не помещаются на текущую страницу, то происходит разбиение (split) страницы.
однако если происходит откат пользовательской транзакции, откат системной транзакции, которая разщепила страницу не происходит 
page split is never rolled back
*/


/*суммарная информация по таблице/индексу
page_count - общее кол-во страниц по каждому индексу для каждого уровня индекса
*/
select * from sys.dm_db_index_physical_stats(db_id('TEST'),OBJECT_ID('dbo.Books'),NULL,NULL,'DETAILED') order by index_id, index_level desc;


/*возвращает первую Data page для определенной таблицы/индекса БД: <имя БД>, <имя таблицы>, <id индекса>
1 строка = 1 страница на всех уровнях индекса + IAM-страница
т.е. сумма page_count из sys.dm_db_index_physical_stats должно быть равно кол-ву строк - 1 (IAM-страница)
*/
DBCC IND ('new', 'Table_1', -1) -- информация по всем страницам всех индексов, если index_id = -1 (???) , возможно все страницы данной таблицы
DBCC IND (new, pers_info, 1) --все страницы индекса с index_id = 1
GO

--посмотреть какая номер файла, страницы и отступ для строк таблицы
SELECT *, sys.fn_PhysLocFormatter (%%physloc%%) AS [Physical RID] FROM tbl;
select *, %%physloc%% from tbl e cross apply sys.fn_PhysLocCracker(%%physloc%%)
select *, %%physloc%% from tbl e 
select *, %%lockres%% from tbl e 

-------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------
/*детальная информация по всем страницам таблицы/индекса*/
----------------------------------------------------------

--вариант 1 (через DBCC IND)
/*
PageFID – the file ID of the page
PagePID – the page number in the file
IAMFID – the file ID of the IAM page that maps this page (this will be NULL for IAM pages themselves as they’re not self-referential)
IAMPID – the page number in the file of the IAM page that maps this page
ObjectID – the ID of the object this page is part of
IndexID – the ID of the index this page is part of
PartitionNumber – the partition number (as defined by the partitioning scheme for the index) of the partition this page is part of
PartitionID – the internal ID of the partition this page is part of
iam_chain_type
PageType – the page type. Some common ones are:
	1 – data page
	2 – index page
	3 and 4 – text pages
	8 – GAM page
	9 – SGAM page
	10 – IAM page
	11 – PFS page
IndexLevel – what level the page is at in the index (if at all). Remember that index levels go from 0 at the leaf to N at the root page
NextPageFID and NextPagePID – the page ID of the next page in the doubly-linked list of pages at this level of the index
PrevPageFID and PrevPagePID – the page ID of the previous page in the doubly-linked list of pages at this level of the index
*/

DBCC IND (TEST, Books, 1)

			--вспомогательная таблица для удобства
			create table #dbcc_ind
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

			insert into #dbcc_ind exec ('DBCC IND (test, Books, 1)')
			select * from #dbcc_ind order by Page_type desc, IAM_chain_type, PrevPagePID

			--станицы индекса
			select * from #dbcc_ind where PageType = 2 order by IndexLevel desc, PagePID
			select page_count from sys.dm_db_index_physical_stats(db_id(),object_id(N'dbo.test'),null,null,'DETAILED')
			where index_level != 0
			--страницы с данными
			select * from #dbcc_ind where PageType = 1
			select page_count from sys.dm_db_index_physical_stats(db_id(),object_id(N'dbo.test'),null,null,'DETAILED')
			where index_level = 0

			/*просмотр корневой страницы индекса*/
			select PagePID from #dbcc_ind where IndexLevel = 2

			truncate table #dbcc_ind



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



-------------------------------------------------------------------------------------------------------------------------

---------------------------------
/*просмотр содержимого страницы*/
---------------------------------

/*включаем флаг DBCC trace*/
DBCC TRACEON(3604) -- вывод данных в консоль, а не в лог
GO

/*dump указанной страницы: <имя БД>, <номер файла>, <номер страницы>, опция для вывода [1,2,3]
DBCC PAGE ( {'dbname' | dbid}, filenum, pagenum [, printopt={0|1|2|3} ]) [WITH TABLERESULTS]
	0 – Prints only page header related information
	1 – Prints page header and page slot array dump with hex dump for each row
	2 – Prints page header and whole page hex dump
	3 – Prints detailed information of per row along with page header
	WITH TABLERESULTS: This clause is optional, this returns the output in tabular format. 

m_pageId = (1:968) : This is the id of the page which we are inspecting. In Sql Server Pages it is stored as FileId:PageId. Here 1 is FileId and 968 is the PageId
m_type = 2 Here m_type value 2 means it is an Index Page, where as value 1 means it is a Data Page and value 10 means it is an IAM page.
m_level = 2 This indicates the level of the page. For example it’s value 0 means it is an leaf level page, page with maximum m_level value with Previous and Next Page id value as NULL (i.e. (0:0)) means it is an Root Page. And pages whose m_level value in-between leaf page and root page m_level values are called intermediate pages. For more details on the Index Structure you can refer to the previous article.
m_prevPage = (0:0) It is the id of the previous page to the current page. Here (0:0) means there are no previous page for this page.
m_nextPage = (0:0) It is the id of the next page to the current page. Here (0:0) means there are no next page for this page.
m_slotCnt = 2 This attribute tells that there are two row offset array (i.e. Page Slot Array) elements pointing to two rows on the page.
m_freeCnt = 8070 This attribute tells the free available space on the page. In this case it is 8070 bytes.
m_ghostRecCnt = 0 When we delete a record, Sql Server doesn’t delete the record on the page. Instead it marks the record as ghost record and removes the pointer to the row from the slot array. This attribute maintains the count of Such ghost records on the page, so that it can be used by the Ghost Clean Process to remove these records later.
*/

select name, database_id from master.sys.databases;

RID: 32:1:73:1
DBCC PAGE(5,1,73,0)
DBCC PAGE ('test',1,73,3)
DBCC PAGE ('test',1,73,3) WITH TABLERESULTS
DBCC PAGE ('new',1,78,3)
DBCC PAGE ('new',1,73,3)
DBCC PAGE (new,1,7202618,1)
DBCC PAGE (new,1,7202618,2)
DBCC PAGE (new,1,7202618,3)



DBCC TRACEOFF
GO



--??????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????



--GAM dump (1:2), (1:511232), ..., (2:3), ...
--(file_number : page_number)
DBCC PAGE(<db_name>,1,2,3) --( {‘dbname’ | dbid}, filenum, pagenum [, printopt={0|1|2|3} ])
GO

--SGAM dump (1:3), (1:511233), ..., (2:3), ...
--(file_number : page_number)
DBCC PAGE(<db_name>,1,3,3)
GO

--info по первой странице IAM + data pages для определенного объекта
DBCC IND(IAMPages, <table_name>,-1)
GO

--IAM dump (1:77)
--(file_number : page_number)
DBCC PAGE(IAMPages,1,77,3)
GO














select * from sys.dm_db_page_info --2019
Select * from sys.dm_db_page_info(6,1,157,'limited')
Select * from sys.dm_db_page_info(6,1,157,'Detailed')

SELECT DMF.*
FROM sys.dm_exec_requests AS DM  
CROSS APPLY sys.fn_PageResCracker (DM.page_resource) AS  fn 
CROSS APPLY sys.dm_db_page_info(fn.db_id, fn.file_id, fn.page_id, 'Detailed') AS DMF










/*проверка на page split is never rolled back*/
CREATE TABLE t1 (c1 INT, c2 VARCHAR (1000));

--не обязательно
CREATE CLUSTERED INDEX t1c1 ON t1 (c1);

INSERT INTO t1 VALUES (1, REPLICATE ('a', 900));
INSERT INTO t1 VALUES (2, REPLICATE ('b', 900));
INSERT INTO t1 VALUES (3, REPLICATE ('c', 900));
INSERT INTO t1 VALUES (4, REPLICATE ('d', 900));
INSERT INTO t1 VALUES (6, REPLICATE ('f', 900));
INSERT INTO t1 VALUES (7, REPLICATE ('g', 900));
INSERT INTO t1 VALUES (8, REPLICATE ('h', 900));
INSERT INTO t1 VALUES (9, REPLICATE ('i', 900));

DBCC IND (test,t1, 1);
select * from sys.dm_db_database_page_allocations(DB_ID('TEST'),object_id('dbo.t1'), NULL, NULL, 'DETAILED')

DBCC TRACEON (3604);
DBCC PAGE (test, 1, 59392, 3);

begin tran

INSERT INTO t1 VALUES (5, REPLICATE ('a', 900));

DBCC IND (test,t1, 1);
select * from sys.dm_db_database_page_allocations(DB_ID('TEST'),object_id('dbo.t1'), NULL, NULL, 'DETAILED')

rollback tran

DBCC TRACEOFF (3604);