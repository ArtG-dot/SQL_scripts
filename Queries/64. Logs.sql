--------------------------------------------------------------------------------------------
--------------------------------------------Info--------------------------------------------
--------------------------------------------------------------------------------------------

-------------------
/*SQL Server Logs*/
-------------------
/*Расположение:
SQL Server: <instance_name> -> Management -> SQL Server Logs
Host (по умолчанию): C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Log\ERRORLOG*/
select SERVERPROPERTY ('ErrorLogFileName') 'ErrorLogFileName' -- текущий файл с логами SQL Server
--тут же лежат dump и trace
/*
SQL Server:		Host:
Current			ERRORLOG
Archive #1		ERRORLOG.1
Archive #2		ERRORLOG.2
...				...				*/


-------------------
/*SQL Server Agent Logs*/
-------------------
/*Расположение:
SQL Server: <instance_name> -> SQL Server Agent -> Error Logs
Host (по умолчанию): C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Log\SQLAGENT.OUT*/
/*
SQL Server:		Host:
Current			SQLAGENT.OUT
Archive #1		SQLAGENT.1
Archive #2		SQLAGENT.2
...				...				*/



/*список всех журналов (архивные и текущий). 
входной параметр xp_enumerrorlogs @p1:
@p1 - журнал какой службы
	1 - журнал SQL Server
	2 - журнал SQL Server Agent
*/
exec master..xp_enumerrorlogs 1
exec master..xp_enumerrorlogs 2

/*журнал
входные параметры xp_readerrorlog @p1, @p2, @p3, @p4, @p5, @p6, @p7, @p8
@p1 - номер журнала (0-6), 0 - текущий журнал
@p2 - журнал какой службы
	1 - журнал SQL Server
	2 - журнал SQL Server Agent
@p3 - фильтра для поиска
@p4 - второе условие для посика
@p5 - с какой даты
@p6 - до какой даты
@p7 - тип сортировки (asc/desc)
@p8 - экземпляр SQL Server
*/
exec master..xp_readerrorlog 0

-----------------------------------------------------------------------------------------------
/*для журнал SQL Server типы процессов: spid.., Server, Logon, Backup, 
с символа * идут строки дампа
*/
if OBJECT_ID('tempdb..#log_num') is not null drop table #log_num;
if OBJECT_ID('tempdb..#log_info') is not null drop table #log_info;

drop table if exists #log_num
drop table if exists #log_info

/*кол-во журналов с логами*/
create table #log_num (num int, dt datetime, size int)
insert into #log_num exec master..xp_enumerrorlogs 1 --	1 - журнал SQL Server,2 - журнал SQL Server Agent
	select * from #log_num

create table #log_info (dt datetime, process varchar(20), log_text varchar(4000))
declare @cnt int = 0

while (@cnt < = (select max(num) from #log_num))
begin
	insert into #log_info exec master..xp_readerrorlog @cnt,1 -- 1 - журнал SQL Server,2 - журнал SQL Server Agent
	set @cnt += 1
end

select *
from #log_info t 
--where t.dt > '2018-12-26 11:00:13.300'
--where t.process = 'Server'
--where t.process = 'Backup' --операция бэкапа
--where t.log_text like '%error%' and t.log_text not like '%errorlog%'--старт сервера
where t.log_text like '%SQL Server is starting at high priority base%' --старт сервера
--where t.log_text like '%I/O requests taking longer than%' --длительная I/O-операция
--where t.log_text like '%10.89.88.87%'
--where t.log_text like '%I/O requests taking longer than%'
and dt > DATEADD(DAY, -10, GETDATE())
order by 1 desc, 2 desc

drop table #log_num;
drop table #log_info;

--------------------------------------------------------------------------------------------
-----------------------------------------Maintaince-----------------------------------------
--------------------------------------------------------------------------------------------
/*изменить уровень логирования для подключения к SQL Server можно руками в SSMS либо с изменением регистра:
ПК на экземпляре -> Properties -> Security -> Login auditing*/

/*расширить кол-во хранимых журналов логов для SQL Server:
<instance_name> -> Management -> SQL Server Logs -> ПК -> Configure */

/*настройка журналов логов для SQL Server:
<instance_name> -> SQL Server Agent -> Error Logs -> ПК -> Configure */