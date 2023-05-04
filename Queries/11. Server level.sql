/*SQL Server supports four types of logins: 
	Windows
	SQL Server
	certificate-mapped
	asymmetric key-mapped*/

--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------

/*все logins (SQL, Windows), участники уровня сервера*/
--## - логины на основе сертфиката
select * from sys.server_principals;
/*	Type:
	S = SQL Login (логин SQL)
	U = Windows Login (логин Windows)
	G = Windows Group (группа Windows)
	R = Server Role (серверная роль)
	C = Certificate Mapped Login (логин, сопоставленный с сертификатом)
	K = Asymmetric Key Metric Login (логин, сопоставленный с ассиметричным ключом)
*/	

/*разрешения уровня сервера*/
select * from sys.fn_builtin_permissions('SERVER') order by permission_name;
select * from sys.server_permissions;

/*разрешения текущего пользователя*/
select * from sys.fn_my_permissions(null,null)
select * from sys.fn_my_permissions(null,'SERVER')

			--каких разрешений нет у текущего пользователя
			SELECT class_desc COLLATE Latin1_General_CI_AI, permission_name COLLATE Latin1_General_CI_AI
			FROM sys.fn_builtin_permissions('SERVER')
			EXCEPT
			SELECT entity_name, permission_name
			FROM sys.fn_my_permissions(NULL, NULL) 

			
-----------------------------------
/*Server-level Roles*/
-----------------------------------
/*cписок ролей уровня сервера*/
exec sp_helpsrvrole;
select * from sys.server_principals where type_desc = 'SERVER_ROLE' order by name;

/*разрешения серверных ролей*/
exec sp_srvrolepermission;

/*сведения о членах ролей уровня сервера*/
exec sp_helpsrvrolemember;
select * from sys.server_role_members;




/*все logins: 
	select * from sys.server_principals where type = 'S' */
select * from sys.sql_logins;


/*список полномочий, учетных данных*/
select * from sys.server_principal_credentials;
select * from sys.credentials;

select * from sys.login_token;

--------------------------------------------------------------------------------------------
------------------------------------------Maintaince----------------------------------------
--------------------------------------------------------------------------------------------
/* разрешения для участника уровня сервера
разрешения fixed server roles в sys.server_permissions не отражены !!!
т.е. principal может иметь доп разрешения */
select p.principal_id
, p.name
, p.type_desc
, p.is_disabled
, p.default_database_name defult_db_nm
, r.class_desc
, ep.name
, r.permission_name
, r.state_desc
, g.name grantor_nm
from sys.server_principals p
left join sys.server_permissions r
	on p.principal_id = r.grantee_principal_id
left join sys.server_principals g
	on r.grantor_principal_id = g.principal_id
LEFT JOIN sys.endpoints ep
	ON r.major_id = ep.endpoint_id
where p.name = 'public'


/*члены указанной серверной роли*/
select pr.principal_id, pr.name, pr.type_desc,
rm.member_principal_id, m.name, m.type_desc, m.default_database_name
from sys.server_principals pr
left join sys.server_role_members rm
	on rm.role_principal_id = pr.principal_id
left join sys.server_principals m
	on rm.member_principal_id = m.principal_id
where pr.name = 'sysadmin';



/*состав всех server roles*/
select [role].name role_nm
--, [role].is_disabled
, [role].create_date
, [owner].name role_owner_nm
, [role].is_fixed_role
, [member].name member_nm
, [member].principal_id
, [member].type_desc
, [member].is_disabled
, [member].create_date
, [member].default_database_name defult_db_nm
--, [member].is_disabled
from sys.server_role_members m
join sys.server_principals [role]
	on m.role_principal_id = [role].principal_id
join sys.server_principals [member]
	on m.member_principal_id = [member].principal_id
join sys.server_principals [owner]
	on [role].owning_principal_id = [owner].principal_id
where [role].name in ('sysadmin', 'serveradmin', 'setupadmin', 'securityadmin', 'processadmin', 'diskadmin', 'dbcreator')
and [member].name not in ('sa')
and [member].name not like 'NT SERVICE\%'
and [member].is_disabled != 1 --активные пользователи



--------------------------
/*создание server logins*/
--------------------------
use master

--создание login на основе windows login
create login [domain\win_login]	from windows with default_database = [Test]

--создание login на основе windows group
create login [domain\win_group]	from windows with default_database = [Test]

--создание SQL Server login
create login [sql_login] with password = N'qwerty123' MUST_CHANGE, default_database = [Test], check_expiration = on, check_policy = on

--создание database user с привязкой к server login
use Test
create user [domain\win_login] for login [domain\win_login]

--настройки логина
USE master;
ALTER LOGIN sa DISABLE; 
ALTER LOGIN sa ENABLE;    
ALTER LOGIN sa WITH PASSWORD = 'qwerty123';

-------------------------
/*настройка server role*/
-------------------------
--создать server role
create server role [my_srv_role]

--разрешения для server role
grant alter any connection to [my_srv_role]
GRANT CONTROL SERVER TO [Role_DBA]
grant connect any database to [my_srv_role]
grant view any database to [my_srv_role]
grant connect sql to [my_srv_role]

--добавить нового члена в группу
alter server role [sysadmin] add member [sql_login]






--------------------------------------------
/*изменить настройки для нескольких logins*/
--------------------------------------------
DECLARE @login_nm nvarchar(50),
		@str nvarchar(4000)

DECLARE cur CURSOR
FOR select *
	from (values
	('user1'),
	('user2'),
	('user3')
	) t(nm)


OPEN cur;
FETCH NEXT FROM cur INTO @login_nm;

WHILE @@fetch_status = 0
BEGIN
	SET @str = 'ALTER LOGIN [' + @login_nm + '] DISABLE;'
	EXEC (@str);
	--print @str

	FETCH NEXT FROM cur INTO @login_nm;
END

CLOSE cur;
DEALLOCATE cur;






revoke view any database to user_test
deny <permission> to user_test



select * from sys.fn_my_permissions(null,null)
select * from sys.fn_my_permissions(null,'SERVER')

