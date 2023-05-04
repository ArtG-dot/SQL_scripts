--------------------------------------------------------------------------------------------
--------------------------------------------Info--------------------------------------------
--------------------------------------------------------------------------------------------
/*Компонент Data Collector (Сборщик данных) позволяет собирать данные о работе SQL-сервера(ов) для дальнейшего анализа.
Сбор происходит на каждом сервере отдельно (т.е. компонент Data Collector настраивается на каждом сервере).
Данные хранятся в отдельном хранилище (Management Data Warehouse, MDW) часто на отдельном сервере.
Перед настройкой Data Collector нужно создать MDW (отдельная пустая БД).

За работу компонента Data Collector (Сборщик Данных) отвечает процесс DCEXEC.EXE (см. в Windows Task Manager)
*/

--------------------------------------------------------------------------------------------
-------------------------------------------Errors-------------------------------------------
--------------------------------------------------------------------------------------------
/*при установки появилась ошибка:
Unable to start collection set Disk Usage.
Msg 14373, Level 16, State 1, Procedure sp_verify_schedule_identifiers, Line 29
Supply either @schedule_id or @schedule_name to identify the schedule.

Решение:
нет расписаний (schedule) необходимых для работы jobs, нужно создать вручную (искать скрипты в интернете):
CollectorSchedule_Every_5min
CollectorSchedule_Every_10min
CollectorSchedule_Every_30min
CollectorSchedule_Every_60min
CollectorSchedule_Every_15min	--с 2012
CollectorSchedule_Every_6h		--с 2012
*/

/*в логах появляются ошибки вида: 
Failed to create kernel event for collection set: {...}. Inner Error ------------------> Cannot create a file when that file already exists.
Данные не собираются.

Решение:
Остановить все версии процесса DCEXEC.EXE
Перезапустить Data Collector: Disable -> Enable
*/

--------------------------------------------------------------------------------------------
-----------------------------------------Maintaince-----------------------------------------
--------------------------------------------------------------------------------------------

-----------------------------
/*включение Data Collector*/
-----------------------------
/*
При включении и настройке Data Collector (для System Data Collection Sets) создаются несколько jobs c category_id = 8 (Data Collector):
collection_set_1_noncached_collect_and_upload
collection_set_2_collection
collection_set_2_upload
collection_set_3_collection
collection_set_3_upload
mdw_purge_data_[MDW]
sysutility_get_cache_tables_data_into_aggregate_tables_daily	(с 2012)
sysutility_get_cache_tables_data_into_aggregate_tables_hourly	(с 2012)
sysutility_get_views_data_into_cache_tables						(с 2012)
*/

/*
1. Настройка MDW:
- создается БД для MDW 
- создается job: mdw_purge_data_[MDW] (очистка хранилища MDW от старых данных )

2. Настройка Data Collection Sets:
- создаются Data Collection Sets 
- создаются jobs: 
	(для Data Collection Sets)
	collection_set_1_noncached_collect_and_upload
	collection_set_2_collection
	collection_set_2_upload
	collection_set_3_collection
	collection_set_3_upload

	(c 2012)
	sysutility_get_cache_tables_data_into_aggregate_tables_daily
	sysutility_get_cache_tables_data_into_aggregate_tables_hourly
	sysutility_get_views_data_into_cache_tables
*/



-----------------------------
/*отключение Data Collector*/
-----------------------------
/*SSMS: 
1. <instance_name> -> Management -> Data Collection -> Data Collection Sets -> ПК -> Stop Data Collection Sets
2. <instance_name> -> Management -> Data Collection -> ПК -> Disable Data Collection*/

/*T-SQL:*/
--отключаем набор(ы) сборщика данных (Data Collection Set(s)) 
exec msdb.dbo.sp_syscollector_stop_collection_set @collection_set_id = 1; 
--отключение jobs для Data Collection Set
exec msdb.dbo.sp_syscollector_stop_collection_set_jobs @collection_set_id = 1;
--отключение сборщика данных
exec msdb.dbo.sp_syscollector_disable_collector

--------------------------------
/*очистка Data Collector и MDW*/
--------------------------------
/*SSMS (удаление jobs не происходит и хранилище не очищается): 
<instance_name> -> Management -> Data Collection -> ПК -> Cleanup Data Collectors*/

/*T-SQL:*/
--1. вып. системную ХП (с 2012), удаляется часть jobs (collection_set_...)
exec msdb.dbo.sp_syscollector_cleanup_collector;
--2. удаляем job mdw_purge_data_[MDW] ([MDW] - имя БД-хранилища)
EXEC msdb.dbo.sp_delete_job @job_name = N'mdw_purge_data_[MDW]';
--3. для 2012 останавливаем jobs sysutility_...
EXEC msdb.dbo.sp_update_job @job_name = N'sysutility_get_cache_tables_data_into_aggregate_tables_daily', @enabled  = 0;
EXEC msdb.dbo.sp_update_job @job_name = N'sysutility_get_cache_tables_data_into_aggregate_tables_hourly', @enabled  = 0;
EXEC msdb.dbo.sp_update_job @job_name = N'sysutility_get_views_data_into_cache_tables', @enabled  = 0;
--4. для 2012 удаляем jobs sysutility_...
EXEC msdb.dbo.sp_delete_job @job_name = N'sysutility_get_cache_tables_data_into_aggregate_tables_daily';
EXEC msdb.dbo.sp_delete_job @job_name = N'sysutility_get_cache_tables_data_into_aggregate_tables_hourly';
EXEC msdb.dbo.sp_delete_job @job_name = N'sysutility_get_views_data_into_cache_tables';
--5. !!!выполнять не рекомендуется!!!, только если есть уверенность, что Data Collector не будет запущен повторно
--удаление расписаний
EXEC msdb.dbo.sp_delete_schedule @schedule_name = N'CollectorSchedule_Every_5min';
EXEC msdb.dbo.sp_delete_schedule @schedule_name = N'CollectorSchedule_Every_10min';
EXEC msdb.dbo.sp_delete_schedule @schedule_name = N'CollectorSchedule_Every_30min';
EXEC msdb.dbo.sp_delete_schedule @schedule_name = N'CollectorSchedule_Every_60min';
EXEC msdb.dbo.sp_delete_schedule @schedule_name = N'CollectorSchedule_Every_15min'; --с 2012
EXEC msdb.dbo.sp_delete_schedule @schedule_name = N'CollectorSchedule_Every_6h';	--с 2012
--6. удаление БД MDW либо отдельных таблиц
