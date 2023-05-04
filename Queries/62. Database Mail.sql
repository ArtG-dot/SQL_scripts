/*проверка что работает Service Broker, он используется дл отправки сообщений*/
select is_broker_enabled from sys.databases where name = 'msdb'

/*список профилей Database Mail (DB Mail Profile)
профили содержат аккаунты (DB Mail Account), с которых идет отправка почты, по сути профиль это упорядоченная коллекция аккаунтов
проложение отправляет почту используя профили, а не аккаунты напрямую
профиль мб Private или Public
каждому пользователю роли DatabasemailUserRole можно назначить свой профиль

оператор это тот кто получает уведомление от DB Mail*/
select * from msdb..sysmail_profile

/*привязка профиля к */
select * from msdb..sysmail_principalprofile

/*список почтовых аккаунтов (учетных записей), от которых происходит отправка писем*/
select * from msdb..sysmail_account

/*список почтовых серверов*/
select * from msdb..sysmail_server
select * from msdb..sysmail_servertype

/*конфигурация компонента DB Mail*/
select * from msdb..sysmail_configuration

/*каждый профиль содержит следующие аккаунты*/
select p.name 'profile_name'
, pa.sequence_number
, a.name 'account_name'
, a.email_address 'account_address'
, a.display_name 'account_display_name'
, a.replyto_address
, p.description 'profile_description'
, a.description 'account_description'
--, a.*
from msdb..sysmail_profile p
left join msdb..sysmail_profileaccount pa
	on p.profile_id = pa.profile_id
join msdb..sysmail_account a
	on pa.account_id = a.account_id


select * from msdb..sysmail_attachments
select * from msdb..sysmail_query_transfer

/*история*/
select * from msdb..sysmail_allitems order by mailitem_id desc;
select * from msdb..sysmail_mailitems order by mailitem_id desc;
select * from msdb..sysmail_sentitems order by mailitem_id desc;
select * from msdb..sysmail_send_retries;
select * from msdb..sysmail_event_log t order by t.log_date desc;
select * from msdb..sysmail_log order by log_date desc;

/*n/a*/
select * from msdb..sysmail_attachments
select * from msdb..sysmail_query_transfer
select * from msdb..sysmail_attachments_transfer

/*список операторов, те кто получает сообщения от DB Mail*/
select * from msdb..sysoperators


--------------------------------------------------------------------------------------------
---------------------------------------Mail Templates---------------------------------------
--------------------------------------------------------------------------------------------
/*результат в виде html-таблицы*/
DECLARE @tableHTML  NVARCHAR(MAX) ;

SET @tableHTML =
N'<table style="border-collapse: collapse; padding: 0pt 5pt; font-size:11pt; font-family:Calibri;">' +  
/* стиль таблицы: border-collapse - нет интервала между ячейками, padding отступ от края ячейки, font-size размер текста, font-family стиль текста */         
N'<tr style="font-weight: bold"><td>srv_name</td><td>job_name</td><td>run_date</td><td>run_time</td><td>step_id</td><td>severity</td></tr>' +
/*стиль заголовка: font-weight: bold - жирный шрифт*/
replace(CAST((select srv_name td, job_name tdъ, run_date tdъъ, run_time tdъъъ, step_id tdъъъъ, severity tdъъъъъ --ъ как уникальный символ, потом удалим
from temp_monitor_jobs 
order by srv_name, job_name, run_date desc, run_time desc
FOR XML PATH('tr'), TYPE) AS NVARCHAR(MAX)),'ъ','') + N'</table>'

select @tableHTML

execute msdb..sp_send_dbmail
	@profile_name=	'tech',
	@recipients =	'my_name@mail.com',
	@from_address =	'tech_email@mail.com',
	@subject =	'Мониторинг JOBs',
	@body =		@tableHTML,
	@body_format = 'HTML';




/*результат в виде html-таблицы*/
if exists (select db_nm, tbl_nm from [test].[dbo].[history_table_delete]
		where db_nm = 'DDD'
		and action_nm = 'rename'
		and action_dt > dateadd(day, -1, GETDATE()))
begin

	DECLARE @tableHTML  NVARCHAR(MAX) ;

	SET @tableHTML =
	N'<p style="border-collapse: collapse; padding: 0pt 5pt; font-size:11pt; font-family:Calibri;">Добрый день. Список переименнованных пустых таблиц из БД KP: </p><br>' +   
	N'<table style="border-collapse: collapse; padding: 0pt 5pt; font-size:11pt; font-family:Calibri;">' +               
    N'<tr style="font-weight: bold"><td>database</td><td>table_name</td></tr>' +
    replace(CAST((select db_nm tr, tbl_nm trъ 
		from [test].[dbo].[history_table_delete]
		where db_nm = db_name()
		and action_nm = 'rename'
		and action_dt > dateadd(day, -1, GETDATE()) order by tbl_nm
	FOR XML PATH('tr'), TYPE) AS NVARCHAR(MAX)),'ъ','') + N'</table>'

	execute msdb..sp_send_dbmail
	@profile_name=	'tech',
	@recipients =	'my_name@mail.com',
	@from_address =	'tech_email@mail.com',
	@subject =	'Переименование пустых таблиц KP',
	@body =		@tableHTML,
	@body_format = 'HTML';
end






/*настройка пользователя под отправку почты*/
use msdb;
go
alter role DatabaseMailUserRole drop member [domain\user]






/*отправка с удаленного SQL-сервера */
declare @str varchar(400);

set @str = 'execute msdb..sp_send_dbmail
	@profile_name=	''tech_upaio'',
	@recipients =	''user@mail.com'',
	@from_address =	''tech@mail.com'',
	@subject =	''script has done'',
	@body =		''OK'',
	@body_format = ''TEXT'';'

exec (@str) at [server-6429]





--------------------------------------------------------------------------------------------
-----------------------------------------Maintaince-----------------------------------------
--------------------------------------------------------------------------------------------
declare @mailitem_id int = 67297;

select * from msdb..sysmail_allitems where mailitem_id = @mailitem_id order by mailitem_id desc;
select * from msdb..sysmail_mailitems where mailitem_id = @mailitem_id order by mailitem_id desc;
select * from msdb..sysmail_sentitems where mailitem_id = @mailitem_id order by mailitem_id desc;
select * from msdb..sysmail_send_retries where mailitem_id = @mailitem_id ;
select * from msdb..sysmail_event_log t where mailitem_id = @mailitem_id order by t.log_date desc;
select * from msdb..sysmail_log where mailitem_id = @mailitem_id order by log_date desc;



--------------------------------------------------------------------------------------------
-------------------------------------------Errors-------------------------------------------
--------------------------------------------------------------------------------------------

Executed as user: . The EXECUTE permission was denied on the object 'sp_send_dbmail', database 'msdb', schema 'dbo'. [SQLSTATE 42000] (Error 229).  The step failed.
--добавить права на отправку почты: alter role DatabaseMailUserRole drop member [V]

Executed as user: . profile name is not valid [SQLSTATE 42000] (Error 14607).  The step failed.
--какой профиль используется при отправке. ДБ публичный (public)