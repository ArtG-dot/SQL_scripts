--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------

SELECT * FROM sys.dm_os_performance_counters 
select * from sys.dm_os_sys_info
select * from sys.dm_os_latch_stats
select * from sys.dm_os_wait_stats order by wait_time_ms desc
select * from sys.dm_os_waiting_tasks 


/*100 самых тяжелых запросов из кэша планов запросов*/
select 
	top 100
	creation_time,
	last_execution_time,
	execution_count,
	total_worker_time/1000 as CPU,
	--convert(money, (total_worker_time))/(execution_count*1000)as [AvgCPUTime],
	total_worker_time/(execution_count*1000)as [AvgCPUTime],
	qs.total_elapsed_time/1000 as TotDuration,
	--convert(money, (qs.total_elapsed_time))/(execution_count*1000)as [AvgDur],
	qs.total_elapsed_time/(execution_count*1000)as [AvgDur],
	total_logical_reads as [Reads],
	total_logical_writes as [Writes],
	total_logical_reads+total_logical_writes as [AggIO],
	--convert(money, (total_logical_reads+total_logical_writes)/(execution_count + 0.0))as [AvgIO],
	total_logical_reads+total_logical_writes/execution_count as [AvgIO],
	case 
		when sql_handle IS NULL then ' '
		else(substring(st.text,(qs.statement_start_offset+2)/2,(
			case
				when qs.statement_end_offset =-1 then len(convert(nvarchar(MAX),st.text))*2      
				else qs.statement_end_offset    
			end - qs.statement_start_offset)/2  ))
	end as query_text,
	db_name(st.dbid)as database_name,
	object_schema_name(st.objectid, st.dbid)+'.'+object_name(st.objectid, st.dbid) as object_name
	, p.query_plan
from sys.dm_exec_query_stats  qs
cross apply sys.dm_exec_sql_text(sql_handle) st
cross apply sys.dm_exec_query_plan(plan_handle) p
where total_logical_reads > 0
order by AvgDur desc



SELECT es.session_id
, ec.connection_id
, es.login_name
, es.host_name
, st.text
, su.user_objects_alloc_page_count
, su.user_objects_dealloc_page_count
, su.internal_objects_alloc_page_count
, su.internal_objects_dealloc_page_count
, ec.last_read
, ec.last_write
, es.program_name
FROM tempdb.sys.dm_db_session_space_usage su
INNER JOIN sys.dm_exec_sessions es ON su.session_id = es.session_id
LEFT OUTER JOIN sys.dm_exec_connections ec ON su.session_id = ec.most_recent_session_id
OUTER APPLY sys.dm_exec_sql_text(ec.most_recent_sql_handle) st







select 
	top 100
	creation_time,
	last_execution_time,
	execution_count,
	total_worker_time/1000 as CPU,
	convert(money, (total_worker_time))/(execution_count*1000)as [AvgCPUTime],
	qs.total_elapsed_time/1000 as TotDuration,
	convert(money, (qs.total_elapsed_time))/(execution_count*1000)as [AvgDur],
	total_logical_reads as [Reads],
	total_logical_writes as [Writes],
	total_logical_reads+total_logical_writes as [AggIO],
	convert(money, (total_logical_reads+total_logical_writes)/(execution_count + 0.0))as [AvgIO],
	case 
		when sql_handle IS NULL then ' '
		else(substring(st.text,(qs.statement_start_offset+2)/2,(
			case
				when qs.statement_end_offset =-1 then len(convert(nvarchar(MAX),st.text))*2      
				else qs.statement_end_offset    
			end - qs.statement_start_offset)/2  ))
	end as query_text,
	db_name(st.dbid)as database_name,
	object_schema_name(st.objectid, st.dbid)+'.'+object_name(st.objectid, st.dbid) as object_name
from sys.dm_exec_query_stats  qs
cross apply sys.dm_exec_sql_text(sql_handle) st
where total_logical_reads > 0
order by AvgDur desc




select 
	creation_time,
	last_execution_time,
	execution_count,
	total_worker_time/1000 as CPU,
	convert(money, (total_worker_time))/(execution_count*1000)as [AvgCPUTime],
	qs.total_elapsed_time/1000 as TotDuration,
	convert(money, (qs.total_elapsed_time))/(execution_count*1000)as [AvgDur],
	total_logical_reads as [Reads],
	total_logical_writes as [Writes],
	total_logical_reads+total_logical_writes as [AggIO],
	convert(money, (total_logical_reads+total_logical_writes)/(execution_count + 0.0))as [AvgIO],
	case 
		when sql_handle IS NULL then ' '
		else(substring(st.text,(qs.statement_start_offset+2)/2,(
			case
				when qs.statement_end_offset =-1 then len(convert(nvarchar(MAX),st.text))*2      
				else qs.statement_end_offset    
			end - qs.statement_start_offset)/2  ))
	end as query_text,
	db_name(st.dbid)as database_name,
	object_schema_name(st.objectid, st.dbid)+'.'+object_name(st.objectid, st.dbid) as object_name,
	qp.query_plan
from sys.dm_exec_query_stats  qs
cross apply sys.dm_exec_sql_text(sql_handle) st
cross apply sys.dm_exec_query_plan(qs.plan_handle) qp
where object_name(st.objectid, st.dbid) = 'SomeProcedure'