--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------
/*список всех JOBs на сервере*/
--notify_level_eventlog - при каких событиях уведомление должно записываться в журнал приложений MS Windows (0-никогда, 1-успехное завершение, 2-ошибка задания, 3-любое завершение)
--notify_level_email - при каких событиях уведомление должно отправляться по почте
--notify_level_netsend - при каких событиях должно быть отправлено сообщение NetSend
--notify_level_page - при каких событиях должна быть отправлена страница(?)
select * from msdb..sysjobs j order by name

/*категории jobs, alerts and operators*/
select * from msdb..syscategories order by 1
/*список всех расписаний (schedules) для jobs*/
select * from msdb..sysschedules
select * from msdb..sysjobschedules
/*взаимосвязи jobs с целевыми серверами*/
select * from msdb..sysjobservers
/*список всех steps по jobs*/
select * from msdb..sysjobsteps


/*регистрация текущих действий и состояния jobs*/
select * from msdb..sysjobactivity --не информативно
/*история по выполнению jobs*/
select * from msdb..sysjobhistory
/*журнал steps при записи истории вне системной таблицы (например в лог-файл (?))*/
select * from msdb..sysjobstepslogs

/*список всех предупреждений (alerts)*/
select * from  msdb..sysalerts
/*список всех увеомлений (notifications)*/
select * from  msdb..sysnotifications
/*список всех operators*/
select * from  msdb..sysoperators



--------------------------------------------------------------------------------------------
------------------------------------------Statistics----------------------------------------
--------------------------------------------------------------------------------------------
/*все jobs на сервере*/
select r.name srv_nm , j.name jb_nm, j.enabled, c.name category, p.name owner, e.name schd_nm, e.enabled schd_enabled
, j.notify_level_email, o.name operator, o.email_address, j.description
from msdb..sysjobs j
left join msdb..sysjobservers s on j.job_id = s.job_id
left join master.sys.servers r on s.server_id = r.server_id
left join msdb..syscategories c on j.category_id = c.category_id
left join master.sys.server_principals p on j.owner_sid = p.sid
left join msdb..sysoperators o on j.notify_email_operator_id = o.id
left join msdb..sysjobschedules h on j.job_id = h.job_id
left join msdb..sysschedules e on h.schedule_id = e.schedule_id
where j.name like 'dbm%' or j.name like 'etl%' or j.name like 'back%'
order by j.name


/*список всех steps для JOBs на сервере*/
select j.name
, j.start_step_id
, s.step_id
, s.step_name
, s.database_name
, s.subsystem
, s.command
from msdb..sysjobs j
left join msdb..sysjobsteps s
	on j.job_id = s.job_id
where 1 = 1 
--and j.name like 'dbm_%'
--j.enabled = 1 
and s.command like '%@shm_nm%'
--order by s.step_name
order by j.name, s.step_id


/*история по выполнению JOB*/
select @@SERVERNAME srv_nm
, j.name jb_nm
, j.start_step_id
, p.name
, h.run_date
, h.run_time
, h.step_id
, h.sql_severity
, h.message
, h.*
from msdb..sysjobs j
left join msdb..sysjobhistory h
	on j.job_id = h.job_id
left join master.sys.server_principals p
	on j.owner_sid = p.sid
where 1 = 1
and j.name like 'dbm_monitor_jobs'
--h.run_date >= 20190101
--and j.name = 'etl_Buffer_ardon_OKR'
--and h.sql_severity <> 0 
order by j.name, h.run_date desc, h.run_time desc, h.step_id desc;


select @@SERVERNAME srv_nm
, j.name jb_nm
, j.start_step_id
, h.run_date
, h.run_time
, h.step_id
, h.sql_severity
, h.message
--, h.*
from msdb..sysjobs j
left join msdb..sysjobhistory h
	on j.job_id = h.job_id
where 1 = 1
--h.run_date >= 20190101
--and j.name = 'etl_Buffer_ardon_OKR'
--and h.sql_severity <> 0 
and (h.job_id is null
or (h.message like '%error%' or h.message like '%fail%'))
and j.category_id != 8 --не Data Collector
order by j.name, h.run_date desc, h.run_time desc, h.step_id desc;



--------------------------------------------------------------------------------------------
------------------------------------------Maintaince----------------------------------------
--------------------------------------------------------------------------------------------
/*создание job (без настройки расписания)*/
USE [msdb]
GO
DECLARE @jobId BINARY(16)

EXEC msdb.dbo.sp_add_job 
	@job_name = N'dbm_rebuild_heap_table_prodDB' 
	, @enabled = 1
	, @owner_login_name = N'sa'
	, @category_name = N'[Uncategorized (Local)]'
	, @description = N'Ребилд таблиц в виде кучи по условию франментации и наличия forwarded records' 
	, @notify_email_operator_name = N'gerasimov-av' --оператор
	, @notify_level_eventlog = 0 --при сбое
	, @notify_level_email = 2 --отправляить по email
	, @job_id = @jobId OUTPUT	
		 
exec msdb.dbo.sp_add_jobserver 
	@job_id = @jobId
	, @server_name = N'(local)'

exec msdb.dbo.sp_update_job 
	@job_id = @jobId
	, @start_step_id = 1

EXEC msdb.dbo.sp_add_jobstep
	@job_id = @jobId
	, @step_id = 1
	, @step_name = N'rebuild heap SMP'
	, @database_name = N'SMP'
	, @cmdexec_success_code = 0
	, @on_success_action = 1 --если успех, (1) то завершить job с успехом, (3) перейти к след шагу
	, @on_fail_action = 2 --если ошибка,  (2) то завершить job с ошибкой
	, @retry_attempts = 0
	, @retry_interval = 0
--	, @os_run_priority = 0
	, @subsystem = N'TSQL'
	, @command = N'declare @frw_rcrd int = 0, --кол-во forwarded record
		@ext_frgmnt int  = 40, --% внешней фрагментации
		@int_frgmnt int  = 50, --% внутренней фрагментации
		@tbl_use_days int = 30, --последнее обращение к таблице было не ранее (текущ. дата - @tbl_use_days * дней)
		@tbl_cnt int = 20, --кол-во таблиц на сжатие за раз (не более)
		@pg_cnt int = 500000; --кол-во страниц на сжатие за раз (не более) (для одной таблицы @pg_cnt*2)

if (object_id(''tempdb..#tmp_tbl'') is not null) drop table #tmp_tbl;

--create table #tmp_tbl (db_nm varchar(50), shm_nm varchar(50), tbl_nm varchar(100), rn int, ttl_pgs int, p_cnt int);

select a.db_nm
	, a.shm_nm
	, a.tbl_nm
	, a.last_user_action
	, a.rows_cnt
	, a.total_pages
	, p.page_count
	, p.compressed_page_count cmprs_page_cnt
	, p.record_count --в общем случае не равно row_count (число записей не равно числу строк, строка может содержать несколько записей)
	, p.forwarded_record_count frwd_record_cnt
	, p.ghost_record_count ghst_record_cnt
	, p.avg_fragmentation_in_percent ext_frgmnt --логич. (внешняя) фрагментация, нужен параметр DETAILED
	, 100 - p.avg_page_space_used_in_percent int_frgmnt --внутренняя фрагментация (% заполнения страницы)
	, ROW_NUMBER() over (order by  a.total_pages) rn
	, sum(a.total_pages) over (order by a.total_pages rows unbounded preceding) p_cnt_sm
	into #tmp_tbl
	from [test].[dbo].[history_table_action] a
	cross apply (select * from sys.dm_db_index_physical_stats(db_id(),a.obj_id,NULL,NULL,''DETAILED'') s 
		where s.index_id = 0	--исключаем NC индексы
		and s.page_count > 1) p
	where a.db_nm = DB_NAME()
	and a.idx_id = 0
	and isnull(a.last_user_action,''1900-01-01'') < dateadd(day, -1, getdate())
	and isnull(a.last_user_action,''1900-01-01'') > dateadd(day, -1*@tbl_use_days, getdate())
	and a.total_pages > 1
--	and a.total_pages < 1000
	and (p.avg_page_space_used_in_percent < (100-@int_frgmnt)  --% заполненности страниц
		or p.forwarded_record_count > 0 --есть forwarded record
		or p.avg_fragmentation_in_percent > @ext_frgmnt) --% внешненй фрагментации
	order by total_pages;

--select * from #tmp_tbl;

if exists (select * from #tmp_tbl)
	begin
		DECLARE @db_nm nvarchar(50),
				@shm_nm nvarchar(50),
				@tbl_nm nvarchar(50),
				@str nvarchar(4000);

		DECLARE cur CURSOR
		FOR select distinct t.db_nm, t.shm_nm, t.tbl_nm 
			from #tmp_tbl t
			where (t.rn <= @tbl_cnt and t.p_cnt_sm < @pg_cnt) or (t.rn = 1 and  t.total_pages < @pg_cnt*2);

		OPEN cur;
		FETCH NEXT FROM cur INTO @db_nm, @shm_nm, @tbl_nm;

		WHILE @@fetch_status = 0
		BEGIN
			SET @str = ''ALTER TABLE ['' + @db_nm  + ''].['' + @shm_nm  + ''].['' + @tbl_nm +''] REBUILD;'' 
--			print @str;
			EXEC (@str);
	
			FETCH NEXT FROM cur INTO @db_nm, @shm_nm, @tbl_nm;
		END

		CLOSE cur;
		DEALLOCATE cur;
	end

drop table #tmp_tbl;'










/*перепривязка всех jobs с одного пользователя на другой*/
exec msdb.dbo.sp_manage_jobs_by_login 
	@action = 'REASSIGN',
	@current_owner_login_name = 'domain/user',
	@new_owner_login_name = 'sa'



/*изменение параметров job*/
sp_update_job [ @job_id =] job_id | [@job_name =] 'job_name'  
     [, [@new_name =] 'new_name' ]   
     [, [@enabled =] enabled ]  -- 1-enable, 0-disable
     [, [@description =] 'description' ]   
     [, [@start_step_id =] step_id ]  
     [, [@category_name =] 'category' ]   
     [, [@owner_login_name =] 'login' ]  
     [, [@notify_level_eventlog =] eventlog_level ]  
     [, [@notify_level_email =] email_level ]  
     [, [@notify_level_netsend =] netsend_level ]  
     [, [@notify_level_page =] page_level ]  
     [, [@notify_email_operator_name =] 'operator_name' ]  
     [, [@notify_netsend_operator_name =] 'netsend_operator' ]  
     [, [@notify_page_operator_name =] 'page_operator' ]  
     [, [@delete_level =] delete_level ]   
     [, [@automatic_post =] automatic_post ]  

EXEC msdb.dbo.sp_update_job @job_name = N'sysutility_get_views_data_into_cache_tables', @enabled  = 0;



/*удалить job*/
EXEC msdb.dbo.sp_delete_job @job_name = N'sysutility_get_cache_tables_data_into_aggregate_tables_daily';



/*изменение настроек для нескольких jobs
для всех jobs смена owner на sa*/
DECLARE @name VARCHAR(1000)
DECLARE My_Cursor CURSOR FOR
	SELECT [name] 
	FROM msdb..sysjobs 
	where name in ('dbm_compression_archDB','dbm_shrink_archDB')
	and enabled = 1
	order by name
 
OPEN My_Cursor
FETCH NEXT FROM My_Cursor INTO @name
WHILE (@@FETCH_STATUS <> -1)
BEGIN
	exec msdb..sp_update_job
			@job_name = @name
			, @enabled = 1
			, @owner_login_name = 'sa'
	FETCH NEXT FROM My_Cursor INTO @name
END 
CLOSE My_Cursor
DEALLOCATE My_Cursor




	SELECT p.name,j.*
	FROM msdb..sysjobs j
	left join master.sys.server_principals p
	on j.owner_sid = p.sid
	where enabled = 1 and p.name != 'sa'
	order by j.name




SELECT j.name, p.name,p.is_disabled, max(h.run_date) last_run
FROM msdb..sysjobs j
left join master.sys.server_principals p
	on j.owner_sid = p.sid
left join msdb..sysjobhistory h
	on j.job_id = h.job_id
where p.name in (select nm
from (values
('domain/user'),
('domain/user2')

) t(nm))
group by j.name, p.name, p.is_disabled
order by j.name


