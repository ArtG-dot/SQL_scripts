select
@@DATEFIRST			--значение параметра SET DATEFIRST, т.е. какой день является началом недели (в рамках сессии)
, @@DBTS			--значение текущего типа данных timestamp для текущей БД
, @@LANGID			--локальный идентификатор языка, кот. используется в данный момент
, @@LANGUAGE		--название языка, кот. используется в данный момент
, @@LOCK_TIMEOUT	--значение времени ожидания для текущего сеанса (если -1, то в текущем сеансе параметр не был задан: SET LOCK_TIMEOUT)
, @@MAX_CONNECTIONS	--максимально допустимое кол-во одновременных connections пользователей с данным экземпляром SQL Server
, @@MAX_PRECISION	--уровень точности для обработки десятичных и числовх типов данных (по умолч. 38)
, @@NESTLEVEL		--уровень вложенности выполняющейся ХП (или триггера) (изначально 0)
, @@OPTIONS			--сведения о текущих параметрах инструкции SET (битовая матрица параметров в виде десятичного числа)
, @@REMSERVER		--имя удаленного сервера БД SQL Server, как указано в учетной записи
, @@SERVERNAME		--имя локального сервера, на котором работает SQL Server
, @@SERVICENAME		--имя экземпляра SQL Server (для экземпляра по умолч. - MSSQLSERVER)
, @@SPID			--идентификатор сеанса для текущего процесса
, @@TEXTSIZE		--текущее значение параметра TEXTSIZE (размер данных типа varchar(max), nvarchar(max), varbinary(max), text, ntext, and image, возвращаемых в запросе SELECT)
, @@VERSION			--сведения о системе и текущей установки SQL Server, отдельные св-ва можно получить используя ф-ю SERVERPROPERTY


, '******************'
--системные ф-ции
, @@CONNECTIONS
, @@CPU_BUSY
, @@CURSOR_ROWS
, @@DEF_SORTORDER_ID
, @@DEFAULT_LANGID
, @@ERROR				--номер последней ошибки при вып. запроса T-SQL
, @@FETCH_STATUS
, @@IDENTITY			--значение последнего вставленного в поле identity (в текущей сессии) (+ SCOPE_IDENTYTI)
, @@IDLE
, @@IO_BUSY
, @@MICROSOFTVERSION	--
, @@PACK_RECEIVED		--кол-во входных пакетов, считанных из сети сервером SQL Server с момента последнего запуска
, @@PACK_SENT	
, @@PACKET_ERRORS
, @@PROCID				--возвращает ID текущего T-SQL модуля (ХП, функции, триггера)
, @@ROWCOUNT			--кол-во строк, затронутых при вып. последней инструкции (если ко-во больше 2млрд, то исп. ROWCOUNT_BIG)
, @@TIMETICKS
, @@TOTAL_ERRORS
, @@TOTAL_READ
, @@TOTAL_WRITE
, @@TRANCOUNT			--кол-во открытых транзакций, т.е. кол-во выполненных инструкций  BEGIN TRANSACTION



--The following scalar functions return information about the database and database objects
select 
@@PROCID					--возвращает ID текущего T-SQL модуля (ХП, функции, триггера)

--,SERVERPROPERTY()

,APP_NAME()					--имя приложения для текущей сессии
--,APPLOCK_MODE()
--,APPLOCK_TEST()

--,DATABASE_PRINCIPAL_ID()
--,DATABASEPROPERTYEX()
,DB_ID()					--id текущей БД
,DB_NAME()					--имя текущей БД
,ORIGINAL_DB_NAME()

--,FILEGROUP_ID()
--,FILEGROUP_NAME()
--,FILEGROUPPROPERTY()

--,FILE_ID()					--id файла по логическому имени
--,FILE_IDEX()				--id файла определенного типа по логическому имени  
--,FILE_NAME()				--логическое имя файла по id
--,FILEPROPERTY()

--,FULLTEXTCATALOGPROPERTY()
--,FULLTEXTSERVICEPROPERTY()

,SCHEMA_ID()
,SCHEMA_NAME()

--,OBJECT_DEFINITION()
--,OBJECT_ID()
--,OBJECT_NAME()
--,OBJECT_SCHEMA_NAME()
--,OBJECTPROPERTY()
--,OBJECTPROPERTYEX()

--,INDEX_COL()
--,INDEXKEY_PROPERTY()
--,INDEXPROPERTY()

--,COL_LENGTH()				--длина поля (в байтах) 
--,COL_NAME()				--имя поля
--,COLUMNPROPERTY()			--св-во поля

--,TYPE_ID()				--id для типа данных
--,TYPE_NAME()
--,TYPEPROPERTY()

--,ASSEMBLYPROPERTY()		--информация о конкретном св-ве определенной сборки

,SCOPE_IDENTITY()
--,NEXTVALUEFOR()			--генерирует след значение из последовательности

--,PARSENAME()

--,STATS_DATE()


