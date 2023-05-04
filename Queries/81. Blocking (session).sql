--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------
/*lock - block - deadlock
lock - это "показатель" того, что-данный ресурс используется в работе, each lock is 96 bytes in size, 
	происходит на уровне транзакций (trancaction logical level)
block - когда одна транзакция ждет освобождение ресурса, с которым работает другая транзакция
deadlock - транзакции блокируют друг друга
latch lock - внутренний объект SQL Server, происходит при распараллеливании потока для контроля страниц, 
	происходит на уровни страниц (phisical pages level)
spin lock

DBA может контролировать lock изменяя уровень изоляции транзакций, latch контролировать нельзя (это делает сам SQL Server)



Lock modes:
Exclusive lock (X) - монопольная блокировка; объект блокируется данной транзакцией от других транзакций; only 1 for object
Shared lock (S) - совмещаемая блокировка; блокировка на чтение данных, несколько транзакций могут устанавливать S блокировку на 1 объект
Update lock (U) - блокировка обновления; м.б. наложена на объект, на котором уже есть S блокировка; похож на X, но более гибкая; 
	Чтобы избежать этой потенциальной взаимоблокировки (deadlock); если на строке U, то S наложить нельзя; only 1 for object
	U блокировка накладывается на строку, если сервер обновляет строки, но пока не знает подподает ли данная страка под условие предиката обновления,  
	если подподает, то U меняется на X блокировку
Intent lock (I): (IS,IX,IU) - блокировка с намернием; указывает на то, что на более низком уровне есть соответствующая блокировка (S,U,X) 
	или что намерение поместить блокировку на более низком уровне
	например устанавливается на таблицу IX, значит какая-то строка таблицы обновляется (X), 
	значит повесить X блокировку на всю таблицу (from other transaction) нельзя
	Intent exclusive (IX) - Защищает запрошенные или полученные X блокировки на ресурсах на более низком уровне иерархии
	Intent shared (IS) - Защищает запрошенные или полученные S блокировки на ресурсах на более низком уровне иерархии.
	Intent update (IU) - м.б. только на уровне страницы, если идет обновление строки, то переходит в IX
	Shared with intent exclusive (SIX) - IX(page) + X(record) блокировки на ресурсах на более низком уровне иерархии
	Shared with intent update (SIU) - Сочетание блокировок S и IU
	Update with intent exclusive (UIX) - Сочетание блокировок U и IX
Schema (Sch): (Sch-M,Sch-S) - блокировка схемы; при модификации структуры таблицы, а не данных
	Schema modification lock (Sch-M) - например при операции rebuild index (одновременный доступ к таблице запрещен)
	Schema stability lock (Sch-S)
Bulk update (BU) - исп. при операции BULK UPDATE совместно с TABLOCK (позволяет поддерживать несколько одновременных потоков массовой 
	загрузки данных в одну и ту же таблицу и при этом запрещать доступ к таблице любым другим процессам)
Range (RS-S, RS-U, RI-N, RI-S, RI-U, RI-X, RX-S, RX-U, RX-X) - for serializable isolation level

Lock resource:
Key (Row): Блокировка для строки в индексе.
RID (Row): Идентификатор строки. Блокировка одной строки в куче.
Page: Блокировка для 8-килобайтовой (КБ) страницы в базе данных.
Extent: Блокировка последовательной группы из 8 страниц.
HoBT (Index ?): Куча или сбалансированное дерево. Блокировка кучи страниц данных или структуры сбалансированного дерева в индексе.
Object (Table): Блокировка для таблицы, хранимой процедуры, представления и т.п., включающая все данные и индексы. Объектом может быть что-либо, 
	для чего имеется запись в таблице sys.all_objects.
File: Блокировка на файл базы данных.
Application: Блокировка на определяемый приложением ресурс.
Metadata: Блокировка элемента данных каталога, также называемого метаданными.
Allocation Unit: Блокировка на единицу распределения.
Database: Блокировка на базу данных, она включает все объекты базы данных.

row level: (X,S,U)
table level: (X,S,IX,IS,SIX), (Sch)--текущие выполняющиеся запросы на сервере

укрупнение блокировок для таблицы (lock escalation):
процесс преобразования большого числа блокировок уровня строки, страницы или индекса в одну блокировку уровня таблицы
ALTER TABLE Table_name
SET (LOCK_ESCALATION = < TABLE | AUTO | DISABLE > –One of those options)
*/

dbcc traceon (1222,-1)

select RAND(checksum(newid()))

/*текущие активные сессии (сеансы) (пользовательские + системные (SID 1-50))
все активные соединения пользователя и внутренних задач
с версии 2012 (11.х) появились новые столбцы*/
select * from sys.dm_exec_sessions where login_name = SUSER_NAME()
--select * from sys.dm_db_session_space_usage

/*текущие активные запросы
с версии 2016 (13.х) появились новые столбцы
если запрос блокирован, то в поле wait_resource указан ресурс, освобождение, которого ожидает запрос
transaction_id - id транзакции, в которой выполняется запрос
cpu_time - время ЦП (мс), затраченное на вып. запроса
total_elapsed_time - общее время (мс) с момента поступления запроса
reads/writes/logical_reads - кол-во операций I/O и лог. чтения
row_count - число строк, возвращенных клиенту по данному запросу
prev_error - последняя ошибка, произошедшая при выпю запроса
granted_query_memory - выделенное чиcло страниц, для вып запроса
dop - степень параллелизма запроса
*/
select * from sys.dm_exec_requests
where session_id > 50 --пользовательские
--where connection_id is not NULL

/*текущие блокировки
resource_description - описание ресурса
request_session_id - id сессии (сеанса)
request_exec_context_id - контекст выполнения запроса
request_owner_id - id определенного владельца запроса
*/
select * from sys.dm_tran_locks where resource_type = 'RID'
select * from sys.partitions where hobt_id = '72057594039697408' --resource_assotiated_entity_id
select * from sys.objects where OBJECT_ID = '405576483'


/*очередность задач на хосте, ожидающих освобождение ресурсов (т.е. вне SQL Server)
например нет свободных потоков (threads) для подключения к SQL Server и эти задачи ждут освобождения потоков
*/
select * from sys.dm_os_waiting_tasks where blocking_session_id is not NULL

/*текущие активные процессы (пользовательские и системные) (будет удалена в след версиях)
системная таблица в которой соспоставляются данные DMV: sys.dm_exec_connections, sys.dm_exec_sessions, sys.dm_exec_requests */
select * from master.dbo.sysprocesses

exec sp_who
exec sp_who2


/*статистика блокировок с начала работы сервера*/
select * from sys.dm_os_wait_stats



/*уровень коннектов/сессий*/
--подключение к серверу (только внешние подключения)
select * from sys.dm_exec_connections
--сессии на сервере (один коннект - одна сессия)
select * from sys.dm_exec_sessions where session_id > 50 --only user sessions, SID <= 50 for system

/*уровень запросов*/
--активные запросы на сервере (один запрос - одна сессия)
select * from sys.dm_exec_requests where session_id > 50

/*уровень транзакций*/
/*активные транзакци на экземпляре*/
select * from sys.dm_tran_active_transactions
/*активные транзакци на уровне БД*/
select * from sys.dm_tran_database_transactions
/*инфо по текущей транзакции*/ 
select * from sys.dm_tran_current_transaction
/*связка сессия-транзакция*/
select * from sys.dm_tran_session_transactions
/*инфо по блокировкам*/
select * from sys.dm_tran_locks


/*уровень потоков*/
select * from sys.dm_os_tasks 
select * from sys.dm_os_threads
select * from sys.dm_os_waiting_tasks 
select * from sys.dm_os_schedulers


select * from master.dbo.sysprocesses



------------------------------------------------------------------------------------------------------------------------------------------------------------------
 
select
at.transaction_id
,re.session_id
,db_name(re.database_id) as db_name
,at.name
,at.transaction_begin_time
,at.transaction_type
,re.status
,re.command
,re.wait_type
,re.reads
,re.writes
--,(select text from sys.dm_exec_sql_text(sql_handle)) as [Query Text]
--,(select query_plan from sys.dm_exec_query_plan(plan_handle)) as [Query Plan] 
from sys.dm_tran_active_transactions as at with(nolock) 
inner join sys.dm_exec_requests as re with(nolock) 
on at.transaction_id = re.transaction_id
where re.session_id > 50
and session_id <> @@spid
and at.transaction_type != 3 --3 - system transaction 
order by at.transaction_begin_time asc 

 
 
/*все блокировки на сервере*/
select t.request_session_id
, d.name
, t.resource_type
, t.resource_subtype
, t.resource_description
, t.resource_associated_entity_id --см. MSDN (для OBJECT это object_id)
, t.request_mode
, t.request_type
, t.request_status
, t.request_exec_context_id
, t.request_request_id
, t.request_owner_type
, t.request_owner_id
, t.lock_owner_address
, w.*
from sys.dm_tran_locks t
left join sys.databases d
       ON t.resource_database_id = d.database_id
left join sys.dm_os_waiting_tasks w
	on t.lock_owner_address = w.resource_address
where t.request_session_id <> @@SPID
--and t.resource_database_id = db_id('test')
--and w.waiting_task_address is not null
--and  t.request_session_id = 94
order by /*t.request_session_id*/  t.request_session_id, t.resource_type



-----------------------------------------------------------------------------------------------------------------------------------------

; with cte as (
	select 
	case 
		when resource_type = 'DATABASE' then 0
		when resource_type = 'FILE' then 0
		when resource_type = 'OBJECT' then 2
		when resource_type = 'PAGE' then 3
		when resource_type = 'KEY' then 4
		when resource_type = 'EXTENT' then 3
		when resource_type = 'RID' then 4
		when resource_type = 'APPLICATION' then 0
		when resource_type = 'METADATA' then 1
		when resource_type = 'HOBT' then 2
		when resource_type = 'ALLOCATION_UNIT' then 2
		else 99
	end l_id
	, l.resource_type, l.resource_database_id, l.resource_description, l.resource_associated_entity_id
	, l.request_mode, l.request_session_id
	from sys.dm_tran_locks l
	group by l.resource_type, l.resource_database_id, l.resource_description, l.resource_associated_entity_id, 
	l.request_mode, l.request_session_id
)
select 
c.request_session_id [SID]
, db_name(c.resource_database_id) db_nm
,
case l_id
when 0 then c.resource_type --+ ' (' + d.name + ')'
else '|' + REPLICATE('____',c.l_id) + c.resource_type
end 'block_tree'
, c.resource_description
, c.resource_associated_entity_id
, c.request_mode
from cte c
where 1 = 1
--and c.request_session_id = 52
and c.request_session_id > 50
order by [SID], db_nm, c.l_id, c.resource_type, c.resource_associated_entity_id




-----------------------------------------------------------------------------------------------------------------------------------------

















select * from sys.dm_exec_query_stats




--Дерево блокировок

SET NOCOUNT ON
GO

SELECT SPID, BLOCKED, REPLACE (REPLACE (T.TEXT, CHAR(10), ' '), CHAR (13), ' ' ) AS BATCH
INTO #T
FROM sys.sysprocesses R CROSS APPLY sys.dm_exec_sql_text(R.SQL_HANDLE) T
GO

select * from #T

WITH BLOCKERS (SPID, BLOCKED, LEVEL, BATCH)
AS
(
	SELECT SPID,
	BLOCKED,
	CAST (REPLICATE ('0', 4-LEN (CAST (SPID AS VARCHAR))) + CAST (SPID AS VARCHAR) AS VARCHAR (1000)) AS LEVEL,
	BATCH FROM #T R
	WHERE (BLOCKED = 0 OR BLOCKED = SPID)
	AND EXISTS (SELECT * FROM #T R2 WHERE R2.BLOCKED = R.SPID AND R2.BLOCKED <> R2.SPID)
	UNION ALL
	SELECT R.SPID,
	R.BLOCKED,
	CAST (BLOCKERS.LEVEL + RIGHT (CAST ((1000 + R.SPID) AS VARCHAR (100)), 4) AS VARCHAR (1000)) AS LEVEL,
	R.BATCH FROM #T AS R
	INNER JOIN BLOCKERS ON R.BLOCKED = BLOCKERS.SPID WHERE R.BLOCKED > 0 AND R.BLOCKED <> R.SPID
)
SELECT N'    ' + REPLICATE (N'|         ', LEN (LEVEL)/4 - 1) +
CASE WHEN (LEN(LEVEL)/4 - 1) = 0
THEN 'HEAD -  '
ELSE '|------  ' END
+ CAST (SPID AS NVARCHAR (10)) + N' ' + BATCH AS BLOCKING_TREE
FROM BLOCKERS ORDER BY LEVEL ASC
GO

DROP TABLE #T
GO



---------------------------------------------------------------------------------------------

--что и кто заблокировал


select     n.session_id as [SID], 
    db_name(i.resource_database_id) as [Database], 
    n.blocking_session_id as [Blocking SID], 
    n.wait_type,
    i.resource_type,
    i.request_status,
    i.request_owner_type,
    i.lock_owner_address,
    n.resource_address
   from sys.dm_tran_locks as i 
   join sys.dm_os_waiting_tasks as n on i.lock_owner_address = n.resource_address
     order by n.session_id asc 


--------------------------------------------------------------------------

--Блокировки от Олега

SELECT  L.request_session_id AS SPID, 
        DB_NAME(L.resource_database_id) AS DatabaseName,
        O.Name AS LockedObjectName, 
        P.object_id AS LockedObjectId, 
        L.resource_type AS LockedResource, 
        L.request_mode AS LockType,
        ST.text AS SqlStatementText,        
        ES.login_name AS LoginName,
        ES.host_name AS HostName,
        TST.is_user_transaction as IsUserTransaction,
        AT.name as TransactionName,
        CN.auth_scheme as AuthenticationMethod
FROM    sys.dm_tran_locks L
        JOIN sys.partitions P ON P.hobt_id = L.resource_associated_entity_id
        JOIN sys.objects O ON O.object_id = P.object_id
        JOIN sys.dm_exec_sessions ES ON ES.session_id = L.request_session_id
        JOIN sys.dm_tran_session_transactions TST ON ES.session_id = TST.session_id
        JOIN sys.dm_tran_active_transactions AT ON TST.transaction_id = AT.transaction_id
        JOIN sys.dm_exec_connections CN ON CN.session_id = ES.session_id
        CROSS APPLY sys.dm_exec_sql_text(CN.most_recent_sql_handle) AS ST
WHERE   resource_database_id = db_id()
ORDER BY L.request_session_id



-- Based on code from Joe Sack
SELECT
	owt.session_id,
	owt.wait_duration_ms,
	owt.wait_type,
	owt.blocking_session_id,
	owt.resource_description,
	es.program_name,
	est.text,
	est.dbid,
	eqp.query_plan,
	es.cpu_time,
	es.memory_usage
FROM sys.dm_os_waiting_tasks owt
INNER JOIN sys.dm_exec_sessions es ON
	owt.session_id = es.session_id
INNER JOIN sys.dm_exec_requests er ON
	es.session_id = er.session_id
OUTER APPLY sys.dm_exec_sql_text (er.sql_handle) est
OUTER APPLY sys.dm_exec_query_plan (er.plan_handle) eqp
WHERE es.is_user_process = 1;
GO