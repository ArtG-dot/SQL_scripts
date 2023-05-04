--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------
/*
SPID - SQL Server Process (session process) ID, уникальный идентификатор для каждого подключения и сеанса SQL Server; 1-50 системные SPIDs; назначает SQL Server
KPID - kernel process ID, это уникальный ID потока (ID thread) для Windows; назначает Windows; это ID контекста выполнения для SQL Server в ОС
ECID - execution context ID, это ID контекста выполнения, для уникальной идентификации подпотоков, по сути это ID подпотока; работающих от имени одного процесса;
*/

/*список endpoints на сервере*/
select * from sys.endpoints

select * from sys.dm_tcp_listener_states

/*активные подключения к текущему экземпляру серверу, вкладка Processes в Activity Monitor*/
select * from sys.dm_exec_connections

/*текущие активные сессии (сеансы) (пользовательские + системные)
все активные соединения пользователя и внутренних задач
с версии 2012 (11.х) появились новые столбцы*/
select * from sys.dm_exec_sessions --session_id 1-50 системные сессии

select * from sys.dm_db_session_space_usage

/*если к SQL Server нельзя подключиться обычным способом, то есть возможность импользовать DAC (Dedicated Administrator Connection).
Это диагностическое соединение для администратора БД. возможно только 1. см. MSDN*/

/*текущие активные запросы на сервере
с версии 2016 (13.х) появились новые столбцы*/
select * from sys.dm_exec_requests 

/*текущие активные процессы (пользовательские и системные)
системная таблица в которой соспоставляются данные DMV: sys.dm_exec_connections, sys.dm_exec_sessions, sys.dm_exec_requests */
select * from master.dbo.sysprocesses

exec sp_who
exec sp_who2

/*агрегированное представление обо всех ожиданиях*/
select * from sys.dm_os_wait_stats ORDER BY wait_time_ms desc
select * from sys.dm_exec_session_wait_stats --(для 2017?)

/*каждая строка - для каждой активной задачи на экземпляре*/
select * from sys.dm_os_tasks 
--	where session_id = 78

/*каждая строка - поток в ОС, запущенный процессором SQL Server*/
select * from sys.dm_os_threads

/*сведения об очереди задач, которые ожидают освобождения определенных ресурсов*/
select * from sys.dm_os_waiting_tasks 
	where session_id = 78
	
/*каждая строка - планировщик SQL Server, сопоставленный с опред процессом*/
select * from sys.dm_os_schedulers
	where scheduler_id < 255

--kill 79 with statusonly
/*суммарная статистика производительности для кэшированных планов запросов
каждая строка - отдельная инструкция в запросе
инфо находится в представлении пока план находится в кэше планов*/
select * from sys.dm_exec_query_stats order by total_elapsed_time desc

/*данные о транзакциях на сервере*/
select * from sys.dm_tran_active_transactions
	where transaction_type != 3 --system transaction

select * from sys.dm_tran_locks  l
where l.request_session_id = 67


select * from sys.dm_os_tasks where task_address not in (
select blocking_task_address from sys.dm_os_waiting_tasks where session_id = 78) and session_id = 78

--------------------------------------------------------------------------------------------
------------------------------------------Maintaince----------------------------------------
--------------------------------------------------------------------------------------------

------------------------------------------------
/*мониторинг активных пользовательских сессий*/
------------------------------------------------
select 
s.session_id
--, c.connection_id
, s.login_name
, s.status
, d.name [db_nm]
, c.connect_time
, s.client_interface_name
, c.net_transport
, c.protocol_type
, s.host_name
, s.host_process_id
, c.client_net_address
, c.client_tcp_port
, c.local_net_address
, c.local_tcp_port
--, s.login_time
, s.cpu_time
, s.memory_usage
, c.num_reads --кол-во считанных байт
, c.num_writes --кол-во записанных байт
, s.reads --кол-во операций чтения
, s.writes --кол-во операций записи
, s.logical_reads --кол-во логических операций чтения
, s.open_transaction_count
, s.last_request_start_time
, s.last_request_end_time
--, s.*
from sys.dm_exec_connections c
left join sys.dm_exec_sessions s
	on c.session_id = s.session_id
left join sys.databases d
	on s.database_id = d.database_id
where s.is_user_process = 1
--and s.status not in ('sleeping')

order by s.session_id

--------------------------------------------------
/*мониторинг активных пользовательских запросов*/
--------------------------------------------------
select 
s.session_id [sid]
--, r.reads --кол-во операций чтения
, r.writes--*8/1024/1024 --кол-во операций записи
, r.logical_reads --кол-во логических 
, s.login_name
, r.status
, DB_NAME(r.database_id) db_nm
--, r.user_id
, cast(r.start_time as smalldatetime) start_time_of_request --время начала исполнения запроса
, r.command
, r.blocking_session_id block_sid
, r.wait_type
, r.wait_time --если запрос ожидает ресурсы, время ожидания
, case when r.wait_time > 1000*60*5 then cast(r.wait_time/1000/60/60 as varchar(5))+ 'ч. ' + cast(r.wait_time/1000/60%60 as varchar(5)) + 'мин. ' + cast(r.wait_time/1000%60 as varchar(5)) + 'сек.' else 'менее 5 мин' end time_of_cur_block
, case when r.total_elapsed_time > 1000*60*5 then cast(r.total_elapsed_time/1000/60/60 as varchar(5))+ 'ч. ' + cast(r.total_elapsed_time/1000/60%60 as varchar(5)) + 'мин. ' + cast(r.total_elapsed_time/1000%60 as varchar(5)) + 'сек.' else 'менее 5 мин' end time_of_request
, r.wait_resource
, r.reads --кол-во операций чтения
, r.writes --кол-во операций записи
, r.logical_reads --кол-во логических операций чтения
, r.row_count --кол-во возвращаемых строк
, r.open_transaction_count open_trn_cnt
, r.cpu_time --общее время рпботы процессора в мс
--, cast(1.*r.cpu_time/r.total_elapsed_time as decimal(4,2)) 'cpu_%'
, r.total_elapsed_time --общее время выполнения запроса в мс
, r.percent_complete --для некоторых команд (BACKUP, RECOVERY, SHRINK и др.)
, r.prev_error --последняя ошибка, полученная при выполнении запроса
, r.nest_level --уровень вложенности кода
, r.granted_query_memory --число страниц выделенное для выполнения запроса
--, r.dop --уровень параллелизма (с 2016)
--, r.parallel_worker_count --кол-во зарезервированных параллельных рабочих процессов (с 2016)
, r.transaction_id
, t.text
, p.query_plan
--, r.*
--, s.*
from sys.dm_exec_requests r
left join sys.dm_exec_sessions s
	on r.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text (r.sql_handle) t --приводим хэш-карту текста SQL-запроса к читаемому виду
OUTER APPLY sys.dm_exec_query_plan(r.plan_handle) p
where 1 = 1 
and r.status not in ('sleeping', 'background') --ожидает, историческая инфа, приостановлен, runnable - готов к исполнению, running - выпоняется, suspended - ожидают, возможно блокированы

--and wait_type = 'OLEDB'
and s.session_id != @@SPID
--and s.session_id in (87)
order by s.session_id



--exec sp_who2

---------------------------------------------------
/*мониторинг активных пользовательских процессов*/
---------------------------------------------------
select 
p.spid --id сеанса SQL Server
, p.kpid --id потока Windows
, p.ecid --id подпроцесса
, p.nt_username --если пусто, то возможно SQL-login, а не Windows-login
, d.name db_nm
, p.loginame --если пусто, то возможно подпроцесс
--, p.hostname --ip хоста, с которого был запущен процесс
--, p.hostprocess --id процесса на хосте
, p.status
, p.blocked --id блокирующего сеанса (сессии)
, p.waittime
--, p.waittype
, p.lastwaittype
, p.waitresource
, p.cpu
, p.physical_io --совокупное кол-во операций чтения и записи для процесса
, p.memusage
, p.open_tran
, p.cmd --команда, которая выполняется в данный момент
, cast(dateDiff( second,last_batch,GETDATE())/60 as varchar)+' Мин '+ cast(dateDiff( second,last_batch,GETDATE())- dateDiff( second,last_batch,GETDATE())/60*60 as varchar)+' Сек' as DateLong
, t.text
--, p.*
from master.dbo.sysprocesses p
left join sys.dm_exec_sessions s
	on p.spid = s.session_id
left join sys.databases d
       ON d.database_id = p.dbid
OUTER APPLY sys.dm_exec_sql_text (p.sql_handle) t
where p.lastwaittype not in (
'SP_SERVER_DIAGNOSTICS_SLEEP' --состояние процесса между выполнением ХП sp_server_diagnostic (сбор статистики по состоянию сервера)
) 
and p.loginame <> 'sa'

--and p.status not in ('sleeping')
and p.spid <> @@SPID
--and p.spid = 55
order by s.session_id, p.ecid




















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
   join sys.dm_os_waiting_tasks as n 
	on i.lock_owner_address = n.resource_address
     order by n.session_id asc 


