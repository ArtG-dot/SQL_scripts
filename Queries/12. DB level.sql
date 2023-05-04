/*Обычная схема дл БД это подключение к серверу через логин (уровень сервера, логины хранятся в БД master). 
Каждый логин ассоциируется c юзером(-ами) в БД.
Эта схема затрудняет перенос БД на другой хост, т.к. там нет необходимых логинов для подключения к БД
Contained Database используют только юзеров, что облегчает перенос БД

В итоге:
для Traditional model
CREATE LOGIN login_name WITH PASSWORD = 'strong_password';
CREATE USER 'user_name' FOR LOGIN 'login_name'; 

для Contained database user model
CREATE USER user_name WITH PASSWORD = 'strong_password';


Every database contains a dbo user and dbo schema.		The dbo user owns the dbo schema.		
Every database contains a guest user and guest schema.	The guest user owns the guest schema.
Every database contains a sys user and sys schema.		The sys user owns the sys schema.
Every database contains a INFORMATION_SCHEMA user and sys schema.		The sys user owns the INFORMATION_SCHEMA schema.

Каждая БД содержит схему dbo и юзера dbo. Не нужно их путать.
SQL Server automatically maps the sa login, database owner, and members of the sysadmin server role to the dbo user account in each database.


 

When you create a user, you can specify a default schema. If you do not, the dbo schema is assumed. 
If you specify a default schema other than dbo and the user is a member of the sysadmin server role, 
the specified schema is ignored and the dbo schema is used. The default schema for all members of sysadmin is dbo.

Users based on logins in master
	CREATE USER [Domain1\WindowsUserBarry]
	CREATE USER [Domain1\WindowsUserBarry] FOR LOGIN Domain1\WindowsUserBarry
	CREATE USER [Domain1\WindowsUserBarry] FROM LOGIN Domain1\WindowsUserBarry
	CREATE USER [Domain1\WindowsGroupManagers]
	CREATE USER [Domain1\WindowsGroupManagers] FOR LOGIN [Domain1\WindowsGroupManagers]
	CREATE USER [Domain1\WindowsGroupManagers] FROM LOGIN [Domain1\WindowsGroupManagers]
	CREATE USER SQLAUTHLOGIN
	CREATE USER SQLAUTHLOGIN FOR LOGIN SQLAUTHLOGIN
	CREATE USER SQLAUTHLOGIN FROM LOGIN SQLAUTHLOGIN

Users that authenticate at the database (for contained database)
	CREATE USER [Domain1\WindowsUserBarry] --be sure that the Windows account is not already associated with a login
	CREATE USER [Domain1\WindowsGroupManagers]
	CREATE USER Barry WITH PASSWORD = 'Qwerty123'

Users based on Windows principals without logins in master
	CREATE USER [Domain1\WindowsUserBarry]
	CREATE USER [Domain1\WindowsUserBarry] FOR LOGIN Domain1\WindowsUserBarry
	CREATE USER [Domain1\WindowsUserBarry] FROM LOGIN Domain1\WindowsUserBarry
	CREATE USER [Domain1\WindowsGroupManagers]
	CREATE USER [Domain1\WindowsGroupManagers] FOR LOGIN [Domain1\WindowsGroupManagers]
	CREATE USER [Domain1\WindowsGroupManagers] FROM LOGIN [Domain1\WindowsGroupManagers]

Users that cannot authenticate
	CREATE USER RIGHTSHOLDER WITHOUT LOGIN
	CREATE USER CERTUSER FOR CERTIFICATE SpecialCert
	CREATE USER CERTUSER FROM CERTIFICATE SpecialCert
	CREATE USER KEYUSER FOR ASYMMETRIC KEY SecureKey
	CREATE USER KEYUSER FROM ASYMMETRIC KEY SecureKey


	
*/


As an example if I impersonate a database principal (user) and query sys.user_token 
I can get a list of all AD groups they are a member of and which ones give them access to the current database.


--------------------------------------------------------------------------------------------
--------------------------------------------Info--------------------------------------------
--------------------------------------------------------------------------------------------
use <db_name>
go

/*список всех возможных разрешений уровня БД*/
select * from sys.fn_builtin_permissions('Database') order by permission_name;
select * from sys.fn_builtin_permissions(NULL) where class_desc = 'DATABASE' order by 2

/*список всех участников (principals) уровня БД*/
select * from sys.database_principals
select * from sys.sysusers order by name
/*	Type:
	S = SQL User (пользователь SQL)
	U = Windows User (пользователь)
	G = Windows Group (группа)
	A = Application Role (роль приложения)
	R = Database Role (роль БД) (fixible и определенные пользователем)
	C = Certificate Mapped User (пользователь, сопоставленный с сертификатом)
	K = Asymmetric Key Metric User (пользователь, сопоставленный с ассиметричным ключом)
*/	

/*назначенные разрешения для участников БД
разрешения fixed roles в sys.database_permissions не отражены!!!
т.е. principal может иметь доп разрешения*/
select * from sys.database_permissions;

/*разрешения текущего пользователя*/
select * from sys.fn_my_permissions(null,null)
select * from sys.fn_my_permissions(null,'SERVER')
select * from sys.fn_my_permissions(null,'DATABASE')
select * from sys.fn_my_permissions('Users','OBJECT')

-----------------------------------
/*Database-level Roles*/
-----------------------------------
/*cписок ролей уровня БД*/
exec sp_helprole;
exec sp_helpdbfixedrole;
select * from sys.database_principals where type_desc = 'DATABASE_ROLE' order by name;

/*список всех разрешения ролей уровня БД*/
exec sp_dbfixedrolepermission;

/*сведения о членах ролей уровня БД*/
exec sp_helprolemember;
select * from sys.database_role_members;


select * from sys.syslogins; --подключенные пользователи
select SUSER_NAME()	login_name	--user’s login identification name
	, SUSER_SNAME()
	, SUSER_ID()	login_id	--user’s login identification number
	, SUSER_SID()	login_sid	--user’s login security identification number (SID)
	, CURRENT_USER
	, USER_ID()		dbuser_name	--user’s database user identification number
	, USER_NAME()	dbuser_id	--user’s database user account name
	, iif (IS_MEMBER('db_owner') = 1, 'is db_owner member', 'is NOT db_owner member')
	--SUSER_SNAME(sid)

select * from sys.extended_properties; --описание объектов БД (колонок таблиц)



SELECT member.name
FROM sys.database_role_members rm
JOIN sys.database_principals role  
  ON rm.role_principal_id = role.principal_id  
JOIN sys.database_principals member  
  ON rm.member_principal_id = member.principal_id
WHERE role.name = 'db_owner'; 




--для sql-модулей: ХП, ф-ций можно посмотреть если они вызываются из под какого-то пользователя (либо из под создавшего этот модуль)
--{ EXEC | EXECUTE } AS { CALLER | SELF | OWNER | 'user_name' } 
select m.object_id, m.execute_as_principal_id, p.name, m.definition
from sys.sql_modules m
left join sys.database_principals p
	on m.execute_as_principal_id = p.principal_id



--------------------------------------------------------------------------------------------
-----------------------------------------Statistics-----------------------------------------
--------------------------------------------------------------------------------------------

/*список прав БД для пользователя*/
declare @user varchar(50) = 'public'

select 
u.name [principal_nm], u.type_desc, u.default_schema_name [default_shm_nm], u.owning_principal_id [owner_id]
, o.name, o.type_desc
, p.permission_name, state_desc, g.name [grantor_nm]
--p.class_desc, o.type_desc, o.name, p.permission_name, p.state_desc
from sys.database_principals u
left join sys.database_permissions p
	on p.grantee_principal_id = u.principal_id
left join sys.objects o
	on o.object_id = p.major_id
left join sys.database_principals g
	on p.grantor_principal_id = g.principal_id
where u.name = @user; --пользователь БД

if (OBJECT_ID('tempdb..#temp') is not null) drop table #temp;
create table #temp (rl_nm varchar(50), rl_perm varchar(100));
insert into #temp exec sp_dbfixedrolepermission;
select u.name [principal_nm], u.type_desc, u.default_schema_name [default_shm_nm], u.owning_principal_id [owner_id],
r.name rl_nm, t.rl_perm
from sys.database_principals u
left join sys.database_role_members m
	on m.member_principal_id = u.principal_id
left join sys.database_principals r
	on m.role_principal_id = r.principal_id
left join #temp t
	on t.rl_nm = r.name
where u.name = @user
order by rl_nm;






/*члены указанной роли БД*/
select pr.principal_id, pr.name, pr.type_desc,
m.name, m.type_desc, m.authentication_type_desc
from sys.database_principals pr
left join sys.database_role_members rm
	on rm.role_principal_id = pr.principal_id
left join sys.database_principals m
	on rm.member_principal_id = m.principal_id
where pr.type_desc = 'DATABASE_ROLE'
--and pr.name = 'db_owner'
order by pr.name;


select IDENT_CURRENT('test_tbl')


--------------------------------------------------------------------------------------------
-----------------------------------------Maintaince-----------------------------------------
--------------------------------------------------------------------------------------------

--создание database user с привязкой к server login
use Test
create user [domain\win_login] for login [domain\win_login]

create user loginless_user without login;


/*смена владельца объекта*/
sp_changeObjectOwner 'dbo.sp_mytest', 'user_nm'


/*права для пользователя*/
grant select on [dbo].[overview] to [domain\user]
grant select on [dbo].overview] to myRole
grant insert on buffer.dbo.table1 to currency_upload_login
grant alter on buffer.dbo.table1 to currency_upload_login

grant create table to [domain\user]
grant alter on schema::dbo to [domain\user]

grant EXECUTE on [dbo].[sp_tabl] to [domain\user]






-------------------------------------
/*Creating Duplicate Database Users*/
-------------------------------------
--подходит, если нужно создать несколько одинаковых users для contained DBs
--для первой contained БД создали user (на основе пароля), получаем его  уникальный SID
USE ImportSales1;
SELECT SID FROM sys.database_principals WHERE name = 'sqluser02'; --0x0105000000000009030000008F5AC110DFB07044AFDADA6962B63B03
--для второй contained БД создаем аналогичного user
USE ImportSales2;
CREATE USER sqluser02 --To create a duplicate Windows-based user, use simple CREATE USER [win\winuser02] statement
	WITH PASSWORD = 'qwerty',
	SID = 0x0105000000000009030000008F5AC110DFB07044AFDADA6962B63B03;

			--можно вып скрипт вида (но нужно корректно настроить параметр TRUSTWORTHY на удаленной БД): ALTER DATABASE ImportSales2 SET TRUSTWORTHY ON;
			EXECUTE AS USER = 'sqluser02'; 
			SELECT * FROM ImportSales1.Sales.Customers
			UNION ALL
			SELECT * FROM ImportSales2.Sales.Customers;
			REVERT; 

/*отсоединить user от login*/
--sp_migrate_user_to_contained system stored procedure for quickly unlinking database users from their associated SQL Server logins 
--все права для user в рамках БД будут сохранены, подключение также будет возможно (т.е. будет user со старым паролем)
	EXEC sp_migrate_user_to_contained   
	@username = N'sqluser03',  
	@rename = N'keep_name',  
	@disablelogin = N'do_not_disable_login';


-------------------------
/*настройка server role*/
-------------------------
create role myRole;
alter role DatabaseMailUserRole drop member [domain\user]
alter role DatabaseMailUserRole add member [domain\user]

------------------------------
/*смена контекста выполнения*/
------------------------------

execute as login = 'domain\user'
	select SUSER_NAME(), SUSER_NAME()
	select * from sys.fn_my_permissions(null,null)
revert

execute as login  = 'domain\user'

select * from overview

select SUSER_NAME()

revert

--просмотр всех разрешения для пользователя
execute as user = 'domain\user'
	select * from sys.fn_my_permissions('Users','OBJECT') order by 1
revert


------------------------------------------------------------------
/*перенос DB на другой сервер и проблема с маппиногом user-login*/
------------------------------------------------------------------
exec sp_change_users_login 'Report';
exec sp_change_users_login 'update_one', 'db_login', 'db_mapped_to_login';
exec sp_change_users_login 'Auto_Fix', 'db_login', null, 'password';


-------------------------------------
/*cross-database ownership chaining*/
-------------------------------------
exec sp_configure 'show advanced', 1
reconfigure
exec sp_configure 'cross db ownership chaining', 1
reconfigure


alter database TEST set db_chaining on;











/*проверка пароля*/
SELECT principal_id, 
  name login_name
FROM sys.sql_logins
WHERE PWDCOMPARE('qwerty123', password_hash) = 1;