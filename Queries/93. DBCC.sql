/*DBCC - Database console commands
Categories:

Maintenance	- Maintenance tasks on a database, index, or filegroup.
Miscellaneous -	Miscellaneous tasks such as enabling trace flags or removing a DLL from memory.
Informational - Tasks that gather and display various types of information.
Validation - Validation operations on a database, table, index, catalog, filegroup, or allocation of database pages.



*/
------------------------------------------------------------------------------------------------------------------------------------------------			
------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------
/*Informational Statements*/
----------------------------

DBCC INPUTBUFFER


--Displays fragmentation information for the data and indexes of the specified table or view.	
DBCC SHOWCONTIG   
[ (   
    { table_name | table_id | view_name | view_id }   
    [ , index_name | index_id ]   
) ]   
    [ WITH   
        {   
         [ , [ ALL_INDEXES ] ]   
         [ , [ TABLERESULTS ] ]   
         [ , [ FAST ] ]  
         [ , [ ALL_LEVELS ] ]   
         [ NO_INFOMSGS ]  
         }  
    ] 
			--пример
			DBCC SHOWCONTIG ('HumanResources.Employee');  --фрагментация для таблицы
			DBCC SHOWCONTIG ('Production.Product', 1) WITH FAST; --сокращенный результат
			DBCC SHOWCONTIG WITH TABLERESULTS, ALL_INDEXES;  --фрагментация для всех индексов на всех таблицах



DBCC OPENTRAN



--общая информация по использованию лог-файла для всех БД: размер журнала транзакций, % заполнения
DBCC SQLPERF   
(	[ LOGSPACE ]							--информация
	| [ "sys.dm_os_latch_stats" , CLEAR ]  --очистка статистики задержек
	| [ "sys.dm_os_wait_stats" , CLEAR ]	--очистка статистики ожиданий
)   [WITH NO_INFOMSGS ]					--без вывода информ сообщений

	--пример
	DBCC SQLPERF (logspace) WITH NO_INFOMSGS --информация

	

DBCC OUTPUTBUFFER


--статусы флагов трассировки	
DBCC TRACESTATUS ( [ [ trace# [ ,...n ] ] [ , ] [ -1 ] ] )   
[ WITH NO_INFOMSGS ]  

			--пример
			DBCC TRACESTATUS(-1);  --все флаги
			DBCC TRACESTATUS (2528, 3205); --флаги 2528, 3205
			DBCC TRACESTATUS();   --все флаги текущей сессии


DBCC PROCCACHE	



--Returns the SET options active (set) for the current connection.
DBCC USEROPTIONS  [ WITH NO_INFOMSGS ] 



--displays current query optimization statistics for a table or indexed view
DBCC SHOW_STATISTICS ( table_or_indexed_view_name , target )   
[ WITH [ NO_INFOMSGS ] < option > [ , n ] ]  
< option > :: =  
    STAT_HEADER | DENSITY_VECTOR | HISTOGRAM | STATS_STREAM 

			--пример
			DBCC SHOW_STATISTICS ("Person.Address", AK_Address_rowguid); --всю информацию по статистике AK_Address_rowguid для индекса "Person.Address"
			DBCC SHOW_STATISTICS ("dbo.DimCustomer",Customer_LastName) WITH HISTOGRAM;  --только гистограмма



			-------------------------------
			 /*!!! недокументированные !!!*/
			 -------------------------------
			--информация по БД (малочитаемая)
			DBCC TRACEON (3604)
			DBCC DBINFO



			--информация по содержанию журнала для указанной БД: VLF, status, etc.
			DBCC LOGINFO (TEST)
			DBCC LOGINFO ('TEST')
	


			--детальная информация из активной части журнала для указанной БД: LSN, TranID, etc.
			DBCC LOG('TEST',-1) WITH TABLERESULTS, NO_INFOMSGS;



			--информация по страницам, принадлежащим таблице/индексу: IAM-pages, Data-pages, Index-pages
			DBCC IND ('new', 'Table_1', -1) -- информация по всем страницам всех индексов, если index_id = -1 (???) , возможно все страницы данной таблицы
			DBCC IND (new, pers_info, 1) --все страницы индекса с index_id = 1



			--детальная информация по указанной страницы
			/*	0 – print just the page header
				1 – page header plus per-row hex dumps and a dump of the page slot array (unless its a page that doesn’t have one, like allocation bitmaps)
				2 – page header plus whole page hex dump
				3 – page header plus detailed per-row interpretation*/
			DBCC PAGE ( {'dbname' | dbid}, filenum, pagenum [, printopt={0|1|2|3} ])



------------------------------------------------------------------------------------------------------------------------------------------------			
------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------
/*Validation Statements*/
----------------------------
DBCC CHECKALLOC	
DBCC CHECKFILEGROUP
DBCC CHECKCATALOG	



--проверка значения св-ва IDENTITY для таблицы, можно вручную поменять значение IDENTITY
DBCC CHECKIDENT
 (
    table_name  
        [, { NORESEED | { RESEED [, new_reseed_value ] } } ]  
)  [ WITH NO_INFOMSGS ]

			--пример
			DBCC CHECKIDENT ('Person.AddressType', NORESEED); --проверка текущего значения
			DBCC CHECKIDENT ('Person.AddressType'); --сброс значения
			DBCC CHECKIDENT('temp6',NORESEED,10); --установка нового значения на 10



DBCC CHECKCONSTRAINTS	
DBCC CHECKTABLE


--проверяет согласовааность БД: запуск DBCC CHECKALLOC и DBCC CHECKCATALOG на БД, DBCC CHECKTABLE на каждой таблице и представлении, 
DBCC CHECKDB     
    [ ( database_name | database_id | 0    
        [ , NOINDEX     
        | , { REPAIR_ALLOW_DATA_LOSS | REPAIR_FAST | REPAIR_REBUILD } ]    
    ) ]    
    [ WITH     
        {    
            [ ALL_ERRORMSGS ]    
            [ , EXTENDED_LOGICAL_CHECKS ]     
            [ , NO_INFOMSGS ]    
            [ , TABLOCK ]    
            [ , ESTIMATEONLY ]    
            [ , { PHYSICAL_ONLY | DATA_PURITY } ]    
            [ , MAXDOP  = number_of_processors ]    
        }    
    ]    
]  
			--пример
			DBCC CHECKDB; 
			DBCC CHECKDB (AdventureWorks2012, NOINDEX);   



------------------------------------------------------------------------------------------------------------------------------------------------			
------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------
/*Maintenance Statements*/
----------------------------



DBCC CLEANTABLE	



DBCC INDEXDEFRAG



DBCC DBREINDEX	



----усечение/сжатие всех файлов (данных и журнала) БД
DBCC SHRINKDATABASE   
( database_name | database_id | 0   
     [ , target_percent ]   
     [ , { NOTRUNCATE | TRUNCATEONLY } ]   
)  [ WITH NO_INFOMSGS ] 

			--пример
			DBCC SHRINKDATABASE (UserDB, 10) --для БД UserDB освободить 10% от занятого файлами
			DBCC SHRINKDATABASE (AdventureWorks2012, TRUNCATEONLY);  --для БД UserDB освободить все свободное место (до последнего размеченного экстента)


--усечение/сжатие определенного файла БД	
DBCC SHRINKFILE   
(   { file_name | file_id }   
    { [ , EMPTYFILE ]   
    | [ [ , target_size ] [ , { NOTRUNCATE | TRUNCATEONLY } ] ]  
    }  
)  [ WITH NO_INFOMSGS ] 

			--пример
			DBCC SHRINKFILE (DataFile1, 7) --для текущей БД файл с именем DataFile1 (файл данных) сжать до 7MB
			DBCC SHRINKFILE (AdventureWorks2012_Log, 1) ----для текущей БД файл с именем AdventureWorks2012_Log (файл лога) сжать до 1MB
			DBCC SHRINKFILE (1, TRUNCATEONLY) --для текущей БД файл усечение файла 1
			DBCC SHRINKFILE (Test1data, EMPTYFILE) --для текущей БД очистить файла Test1data



--Reports and corrects pages and row count inaccuracies in the catalog views. 
DBCC UPDATEUSAGE   
(   { database_name | database_id | 0 }   
    [ , { table_name | table_id | view_name | view_id }   
    [ , { index_name | index_id } ] ]   
) [ WITH [ NO_INFOMSGS ] [ , ] [ COUNT_ROWS ] ]  

		--пример
		DBCC UPDATEUSAGE (0); --Updating page or row counts or both for all objects in the current database
		DBCC UPDATEUSAGE (AdventureWorks2012) WITH NO_INFOMSGS --Updating page or row counts or both for AdventureWorks, and suppressing informational messages
		DBCC UPDATEUSAGE (AdventureWorks2012,'HumanResources.Employee') --Updating page or row counts or both for the Employee table
		DBCC UPDATEUSAGE (AdventureWorks2012, 'HumanResources.Employee', IX_Employee_OrganizationLevel_OrganizationNode); --Updating page or row counts or both for a specific index in a table



--Removes all clean buffers from the buffer pool, and columnstore objects from the columnstore object pool.
DBCC DROPCLEANBUFFERS [ WITH NO_INFOMSGS ]  



--Removes all elements from the plan cache, removes a specific plan from the plan cache by specifying a plan handle or SQL handle, 
--or removes all cache entries associated with a specified resource pool.
DBCC FREEPROCCACHE [ ( { plan_handle | sql_handle | pool_name } ) ] [ WITH NO_INFOMSGS ]  	

			--пример
			DBCC FREEPROCCACHE --удаление всех элементов поцедурного кеша
			DBCC FREEPROCCACHE WITH NO_INFOMSGS --подавляет вывод информ. сообщений
			DBCC FREEPROCCACHE (0x06000700FED25D30405E22286B00000001000000000000000000000000000000000000000000000000000000) --удаление конкретного плана из кэша, можно указать либо sql_handle, 

			

--очищает кэш соединений распределенных запросов, используемый для распределенных запросов к экземпляру Microsoft SQL Server
DBCC FREESESSIONCACHE [ WITH NO_INFOMSGS ]  	



----Удаляет все неиспользуемые элементы из всех кэшей
DBCC FREESYSTEMCACHE   
    ( 'ALL' [, pool_name ] )   
    [WITH   
    { [ MARK_IN_USE_FOR_REMOVAL ] , [ NO_INFOMSGS ]  }  
    ]  
			--пример
			DBCC FREESYSTEMCACHE('ALL')	



			-------------------------------
			 /*!!! недокументированные !!!*/
			 -------------------------------

			 --очистка кэша по ID БД*/
			DBCC FLUSHPROCINDB(dbid)



------------------------------------------------------------------------------------------------------------------------------------------------			
------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------
/*Miscellaneous Statements*/
----------------------------

DBCC dllname (FREE)	
DBCC HELP
DBCC FLUSHAUTHCACHE	

DBCC TRACEON  --включение флага трассировки
DBCC TRACEON (3604) --трассировка в окно результата, а не в лог
DBCC TRACEON (8666) --трассировка для просмотра плана выполнения для CCI (появляется объект Deleted Buffer)

DBCC TRACEOFF --выключение флага трассировки

			--флаги трассировки мб глобальные, уровня сессии и уровня запроса


DBCC CLONEDATABASE 

 






 -------------------------------
 /*!!! недокументированные !!!*/
 -------------------------------


DBCC COLLECTSTATS ('on' | 'off') --This command can be used to turn on/off cache statistics.
--для включения/выключения сбора статистики кэша

DBCC CURSORSTATS ([spid [,'clear']]) --This DBCC command returns an aggregate collection of statistics for cursor usage.
spid – is a process ID, which can be returned by the sp_who system stored procedure.
clear – used to clear the cursor statistics.
DBCC CURSORSTATS (@@SPID)

DBCC DETACHDB ( ‘dbname’ [, fKeep_Fulltext_Index_File (0 | 1)] ) --This command is used to detach SQL Server 2014 database, but the more correct way is using the sp_detach_db system stored procedure as a documented way to accomplish the same task

DBCC FILEHEADER ({‘dbname’ | dbid} [, fileid]) --This command returns logical file name, file size, growth increment and so on.
dbname | dbid – is a database name or database ID
fileid – is a file identificator
DBCC FILEHEADER (TEST,1)







DBCC INVALIDATE_TEXTPTR_OBJID (objid) --This DBCC command can be used to invalidate in-row text pointers for table.

DBCC SQLMGRSTATS --This command returns three values that shows how caching is being performed on ad-hoc and prepared
--возвращает три значения, которые показывают, как выполняется кэширование прямых и подготовленных команд -SQL
Memory Used (8k Pages) – cache size for the ad-hoc and prepared -SQL statements.
Number CSql Objects – is the total number of cached -SQL statements.
Number False Hits – wrong attempts to get prepared -SQL statements from the cache.

Memory Used (8k Pages) - размер кэша для прямых и подготовленных команд -SQL.
Number CSql Objects - общее количество кэшированных команд -SQL.
Number False Hits - количество неверных попыток получения подготовленных команд -SQL из кэша.



DBCC AUDITEVENT (eclass, esclass, success, lname, rname, uname, lid, oname, sname, pname) --для включения аудита определенного события
eclass - класс события. Вы можете увидеть список всех доступных классов событий в описании системной хранимой процедуры sp_trace_setevent в SQL Server Books Online.
esclass - подкласс события.
success - значение 0|1.
lname - имя логина для отслеживания события.
rname - имя роли для отслеживания события.
uname - имя пользователя базы данных для отслеживания события.
lid - ID логина для отслеживания события.
oname - имя объекта для отслеживания события.
sname - имя сервера для отслеживания события.
pname - имя провайдера для отслеживания события.



DBCC CALLFULLTEXT -- для удаления всех каталогов полнотекстового поиска из текущей базы данных
--для изменения свойств службы Full-Text Search, таких, как задержка индексирования (pause indexing), обновление языков (update languages) и проверка подписи (verify signature).
DBCC CALLFULLTEXT (7, @dbid) --удаляет все каталоги полнотекстового поиска из текущей базы данных
DBCC CALLFULLTEXT (18) --обновляет список языков, зарегистрированных для службы Full-text Search




