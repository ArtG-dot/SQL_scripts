/*
Plan Cache pollution.

Если есть несколько одинаковых запросов но с разными явными значениями, то SQL Server запишет в кэш планы для каждого из запросов:
select * from <table> where ID = 1;
select * from <table> where ID = 2;
select * from <table> where ID = 3;
получаем 3 плана, т.е. SQL Server зря расходует ресурсы на расчет плана выполнения.

Если мы используем запрос с параметром:
select * from <table> where ID = @id;
то получаем только 1 план, который может быть использован повторно (экономия ресурсов)

!!! проверить!!!
SQL Server может может выполнять запросы используя параллельные вычисления.
Т.о. на одн запрос могут быть скомпилированы 2 плана: обычный и параллельный, оба они сохраняются в кэш
какой будет использован, зависит от ситуации
*/



/*
параметры
Estimated I/O Cost
Estimated CPU Cost
оцениваются в условных единицах, причем единицы одинаковые
т.е. если Estimated I/O Cost = 3,32 и Estimated CPU Cost = 0,054 то это значит что данный оператор сильно нагружает систему ввода/вывода
*/

/*свойство БД parametrization:
forced - параметризация всех запросов
simple - параметризация простых запросов

используя sp_executesql с параметрами также параметризирует план запроса

смена контекста выполнения также приводит к рекомпиляции планов и их нельзя использовать повторно
например set ansi_null on/of
т.о. нужно устанавливать эти параметры на сесиию и как можно реже

каждая таблица имеет порог рекомпиляции, который зависит от	кол-ва модификаций:
постоянные: если число записей <= 500, то порог рекомпиляции (recompilate treshold, RT) = 500
			если число записей > 500, то порог рекомпиляции (recompilate treshold, RT) = 500 + 0.2*число записей

временные:	если число записей < 6, то порог рекомпиляции (recompilate treshold, RT) = 6
			если 6 < число записей < 500, то порог рекомпиляции (recompilate treshold, RT) = 500 
			если число записей > 500, то порог рекомпиляции (recompilate treshold, RT) = 500 + 0.2*число записей

для табличных переменных RT не существует
*/


/*
SQL Server строит планы для этих типов объектов:
хранимые процедуры
скалярные функции
Multi-step табличные функции
триггеры
*/

--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------

/*все кэшированные планы для всего сервера:
refcpunts - число объектов кэша, ссылающиеся на данный объект
usecounts - Количество повторений поиска объекта кэша. Остается без увеличения, если параметризованные запросы обнаруживают план в кэше. Может быть увеличен несколько раз при использовании инструкции showplan.
objtype : Prepared-Подготовленная инструкция, Adhoc-Нерегламентированный запрос
plan_handle - идентификатор плана в кеше

sql_handle references the SQL statement (batch) that has been executed (points to the source code)
plan_handle references the execution plan for the executed SQL statement (points to the compiled object code). Can be correlated to 1 or more SQL_Handles, as a query plan can consist of 1 or more statements

при выполнении пакета кэшируется каждая инструкция в пакете (Compiled Plan::Prepared) + сам пакет (Compiled Plan::Adhoc)
Prepared - скомпилированный параметризированный запрос
Adhoc - весь пакет
Если пакет отличается (например на знак пробела), то Adhoc будет новый, а Prepared остануться те же.
*/
select * from sys.dm_exec_cached_plans 
	where cacheobjtype = 'Compiled Plan' 
	order by plan_handle

/*статистика производительности для кэшированных планов запросов (!!!) с разделением на отдельные инструкции*/
select * from sys.dm_exec_query_stats 

			/*все планы запросов в кеше с разбивкой по отдельным инструкциям*/
			select 
			DB_NAME(p.dbid) db_nm
			, c.cacheobjtype
			, c.objtype
			, c.refcounts 
			, c.usecounts use_cnt
			, DENSE_RANK() over (order by c.objtype, c.plan_handle) batch_num
			, ROW_NUMBER() over (partition by s.sql_handle order by s.statement_start_offset) tsql_num
			, ltrim(replace(replace(iif(c.objtype='Adhoc', SUBSTRING(t.text, s.statement_start_offset/2, (s.statement_end_offset - s.statement_start_offset)/2 + 2), t.text), nchar(10), nchar(32)),nchar(9), nchar(32))) sub_statement --выводим отдельный запрос из пакета, хз почему длина + 2
			, s.statement_start_offset stmnt_from--в байтах
			, s.statement_end_offset stmnt_to--в байтах
			, s.creation_time
			, s.last_execution_time
			, s.execution_count exec_cnt
			, t.text batch_text
			, p.query_plan batch_plan
			, s.*
			from sys.dm_exec_cached_plans c
			JOIN sys.dm_exec_query_stats s on c.plan_handle =s.plan_handle
			OUTER APPLY sys.dm_exec_sql_text (s.sql_handle) t --приводим хэш-карту текста SQL-запроса к читаемому виду
			OUTER APPLY sys.dm_exec_sql_text (s.plan_handle) t1 --то же самое что и t
			OUTER APPLY sys.dm_exec_query_plan(s.plan_handle) p
			where p.dbid = DB_ID('TEST')
			and (t.text like '%Books%'or t.text like '%people%') and t.text not like '%dm_exec_cached_plans%'
			order by batch_num, tsql_num


--текущие выполняющиеся запросы на сервере
select * from sys.dm_exec_requests 
	where session_id > 50
	
		



select * from sys.dm_os_wait_stats
select * from sys.dm_os_performance_counters

select * from sys.dm_io_virtual_file_stats()

select * from sys.dm_exec_query_memory_grants
select * from sys.dm_exec_query_stats




/*руководство планов (Plan Guide) позволяют оптимизировать запросы с случаях, когда нет возможности изменить текст запроса
(например еслииспользуется внешнее приложение)
с помощью руководства оптимизатору задаются нужные подсказки и SQL Server добавляет некоторые условия OPTIONS при получении запроса

Создание:
1) DB -> Programmability -> Plan Guides
2) sp_create_plan_guide

нужно коррекно указывать текст запроса и параметры для этого запроса (чаще всего запрос вып через sp_executesql)
*/



set showplan_all on;
set showplan_text on;
set showplan_xml on;






--1. выполняем сброс грязных страниц из памяти (буфферный кеш) на диск, чистим буфферы
CHECKPOINT

--2.a. Очистка кеша планов (кэша процедур, plan cache, procedure cache) 
--также перенастройка некоторых системных параметров вызывает очистку кэша планов
DBCC FREEPROCCACHE --удаление всех элементов поцедурного кеша
	DBCC FREEPROCCACHE WITH NO_INFOMSGS --подавляет вывод информ. сообщений
	DBCC FREEPROCCACHE (0x06000700FED25D30405E22286B00000001000000000000000000000000000000000000000000000000000000) --удаление конкретного плана из кэша, можно указать либо sql_handle, либо plan_handle
alter database scoped configuration clear procedure_cache --c 2016


/*!!!недокументированная команда!!! очистка кэша по ID БД*/
DBCC FLUSHPROCINDB(dbid)
  

DBCC FREESESSIONCACHE --очищает кэш соединений распределенных запросов, используемый для распределенных запросов к экземпляру Microsoft SQL Server


DBCC FREESYSTEMCACHE('ALL') --Удаляет все неиспользуемые элементы из всех кэшей


--2.b. удаление буфферов из buffer pool
--можно исп. для проверки запроса на "холодном" (пустом) буфферном пуле
DBCC DROPCLEANBUFFERS --Removes all clean buffers from the BUFFER POOL, and columnstore objects from the columnstore object pool.
	DBCC DROPCLEANBUFFERS WITH NO_INFOMSGS --подавляет вывод информ. сообщений


exec sp_recompile
























/*настройки параметризации*/


EXEC sp_create_plan_guide
  @name=N'PlanGuide_Demo', 
  @stmt=N'SELECT * FROM AdventureWorks2012.Sales.CreditCard WHERE CreditCardID = @CID', 
  @type = N'TEMPLATE', 
  @module_or_batch = NULL, 
  @params = N'@CID int', 
  @hints = N'OPTION(PARAMETERIZATION SIMPLE)'; 
GO











/*Simple and Forced Parameterization*/
DBCC FREEPROCCACHE (0x0600050083E96A19001981AB1000000001000000000000000000000000000000000000000000000000000000)

--простой запрос (ad-hoc), попытка паратетризировать запрос
SELECT * FROM AdventureWorks2012.Sales.CreditCard WHERE CreditCardID = 11
SELECT * FROM AdventureWorks2012.Sales.CreditCard WHERE CreditCardID = 12

select p.*, h.*
from sys.dm_exec_cached_plans p
OUTER APPLY sys.dm_exec_sql_text (p.plan_handle) h
where p.cacheobjtype = 'Compiled Plan'
	and h.dbid = DB_ID()
	and h.text like '%AdventureWorks2012%'
order by p.usecounts desc


SELECT name, is_parameterization_forced FROM sys.databases
 --Forced
ALTER DATABASE AdventureWorks2012 SET PARAMETERIZATION FORCED

--Simple
ALTER DATABASE AdventureWorks2012 SET PARAMETERIZATION SIMPLE


EXEC sp_create_plan_guide
  @name=N'PlanGuide_Demo', 
  @stmt=N'SELECT * FROM AdventureWorks2012.Sales.CreditCard WHERE CreditCardID = @CID', 
  @type = N'TEMPLATE', 
  @module_or_batch = NULL, 
  @params = N'@CID int', 
  @hints = N'OPTION(PARAMETERIZATION SIMPLE)'; 
GO

