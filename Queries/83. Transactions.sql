--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------
/*
implicit transaction - неявная транзакция (set implicit_transactions on, begin автоматически, commit/rollback вручную)
explicit transaction - явная транзакция (begin/commit вручную)
autocommit



при настройке isolation level мы можем контролировать только операцию чтения, т.е. влиять на shared locks (как долго и каким образом мы держим shared lock на объекте)
операцию записи мы контролировать не можем

4 основных уровня - pessimistic isolation level (concurency)
2 доп уровня - optimistic isolation level (concurency)

transaction isolation level:
READ UNCOMMITTED: не накладываем S-lock на считываемый объект; т.о. можем прочитать незафискисированные данные (грязное чтение)
READ COMMITTED: накладываем S-lock на считываемый объект; как только прочитали, снимаем S-lock, не дожидаясь конца транзакции
	(+ наcтройка уровня БД READ_COMMITTED_SNAPSHOT, RCSI-read committed snapshot isolation): если настройка OFF, то используем S-lock; если ON, то используется версионность строк (старые версии строк хранятся в tempdb и чтение происходит отсюда)
REPEATABLE READ: накладываем S-lock на считываемый объект; не снимаем S-lock до конца транзакции
SNAPSHOT: при каждой операции чтения предоставляет данные, которые были на начало транзакции, даже когда транзакция по изменению данных уже завершилась; данные на налало транзакции хранятся в tempdb
SERIALIZABLE: накладываем S-lock на считываемый объект; не снимаем S-lock до конца транзакции; нельзя изменять (insert, update) другие данные, если они попадут под условие чтения текущей транзакции
	исп key range lock технологию (т.е. блокируем не отдельные строки, а диапазон);
	для NCI накладывается S-lock на все записи (record), если строк более 5000, то блокировка накладывается S-lock на всю таблицу, таблица становится read-only


отличие READ COMMITTED SNAPSHOT ISOLATION и ISOLATION LEVEL SNAPSHOT в том как ведет себя операция повторного чтения после фиксации изменений в данных:
READ COMMITTED SNAPSHOT ISOLATION - мы получаем новые данные, т.е. те данные, которые зафиксированы на текущий момент
ISOLATION LEVEL SNAPSHOT - мы получаем "исходные" данные, т.е. те данные, которые были зафиксированы на момент начала транзакции чтения

*/

--уровень изоляции (4 основных, pessimistic)			табличный указатель
set transaction isolation level read uncommitted		READUNCOMMITTED, NOLOCK 
set transaction isolation level read committed			READCOMMITTED (зависит от READ_COMMITTED_SNAPSHOT), READCOMMITTEDLOCK (не зависит от READ_COMMITTED_SNAPSHOT)
set transaction isolation level repeatable read			REPEATABLEREAD
set transaction isolation level serializable			SERIALIZABLE, HOLDLOCK

--уровень изоляции snapshot (row version, optimistic)
ALTER DATABASE TEST SET ALLOW_SNAPSHOT_ISOLATION ON --т.о. сервер может (но не должен) использовать уровень изоляции snapshot
set transaction isolation level snapshot

--установка уровеня изоляции Read Committed Snapshot Isolation (RCSI), д.б. только 1 сессия к БД
set transaction isolation level read committed	--устанавливаем read committed level
ALTER DATABASE TEST SET READ_COMMITTED_SNAPSHOT ON --переводим БД в режим optimistic, в этом режиме Read Committed меняется на Read Committed Snapshot Isolation

			--отключаем RCSI
			ALTER DATABASE TEST SET READ_COMMITTED_SNAPSHOT OFF --RCSI переходит в read committed

--просмотр уровня узоляции сессии
dbcc useroptions


---------------------------------------------------------------------------------------------------------------------------------------------

--длинные транзакции


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
	  ,re.estimated_completion_time
	  ,re.cpu_time
	  ,re.total_elapsed_time
	  ,re.row_count
	  ,re.logical_reads
      --,(select text from sys.dm_exec_sql_text(sql_handle)) as [Query Text]
      --,(select query_plan from sys.dm_exec_query_plan(plan_handle)) as [Query Plan] 
      from sys.dm_tran_active_transactions as at with(nolock) 
      inner join sys.dm_exec_requests as re with(nolock)
            on at.transaction_id = re.transaction_id
      where re.session_id > 50
            and re.session_id <> @@spid
            and at.transaction_type = 1 
            or at.transaction_type = 4
            order by at.transaction_begin_time asc

select * from sys.dm_exec_requests
/*инфо по блокировкам*/
select * from sys.dm_tran_locks
select * from sys.dm_os_waiting_tasks 

begin tran

select @@TRANCOUNT
commit
rollback


set im
select 1/0
select @@error






select @@VERSION

select * from sys.dm_tran_active_transactions;

select * from sys.indexes order by fill_factor;
select @@TRANCOUNT;
select XACT_STATE();
begin tran
select * from temp2;
select @@TRANCOUNT;
select XACT_STATE();
	begin tran
	select @@TRANCOUNT;
	select XACT_STATE();
	commit tran 
commit tran
select @@TRANCOUNT;
select XACT_STATE();

exec sp_configure 'fill factor'
