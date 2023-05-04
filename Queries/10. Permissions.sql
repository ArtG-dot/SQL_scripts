/*
SQL Server управляет разрешениями на уровне сервера, БД, объектов:
Authentification
Authorization

SQL Server supports two authentication modes: Windows Authentication; SQL Server and Windows Authentication (mixed mode)
Instance -> ПК -> Properties -> Security

Securables (объекты безопасности) - сервер, БД, объекты БД (таблицы, ХП, представления и тп) (server level, db level, schema level)
Permissions (разрешения) - действия, которые можно совершать с объектами безопасности (Securables)
Principals (субъекты безопасности) - кому выдаются разрешения (Permissions) на объекты (Securables) (logins, users, roles)


Управление разрешениями происходит как на уровне сервера, так и на уровне БД:
уровень сервера - server logins, server roles, server permissions (управление подключением к instance)

уровень БД - database users, database roles, database permissons
объекты - schemas, object permission, ownership chaining


Principals (субъекты безопасности) - кому можно дать разрешения на опредеденные действия.
Т.е. это сущности, которые могут запрашивать ресурсы SQL Server. 
М.б. групповые и индивидуальные, а также различаться по области определения (Windows -> SQL Server -> Database -> DB objects)
Principals это logins, Fixed Server Roles, User-defined Server Roles, Database Users, Fixed Database Roles, User-defined Database Roles, другие Principals

Azure principals:
	Azure AD login for AD user
	Azure AD login for AD group

Windows level principals:
	Windows domain login
	Windows local login
	Windows group

SQL Server-level principals:
	SQL Server login
	SQL Server Role							= Fixed Server Roles (9 встроенных ролей) + User-defined Server Roles
	Standalone login						= к нему не привязан user на уровне БД

Database-level principals:
	Database user							(SQL_USER, WINDOWS_USER)
	Database Role							= Fixed Database Roles (9 встроенных ролей) + User-defined Database Roles
	Application Role
	Standalone user							= к нему не привязан login на уровне server

sa - server-level principal, член роли sysadmin, обладает всеми правами на сервере, 
этот логин нельзя ограничен или удалить, но можно отключить.You cannot drop the sa login, but you can disable it. 
If you select Windows Authentication when installing SQL Server, the database engine assigns a random password to the account 
and automatically disables it. If you then switch to SQL Server Authentication, the login remains disabled, and you must manually enable it.

Every database contains a dbo user and dbo schema.		The dbo user owns the dbo schema.		
Every database contains a guest user and guest schema.	The guest user owns the guest schema.
Every database contains a sys user and sys schema.		The sys user owns the sys schema.
Every database contains a INFORMATION_SCHEMA user and sys schema.		The sys user owns the INFORMATION_SCHEMA schema.

public Server and Database Roles
	Each SQL Server instance contains the public fixed server role, and each database (including system databases) contains the public fixed database role
	All logins belong to the public server role, and all database users belong to the public database role
	You cannot drop either role, and you cannot add members to or remove members from either role.
	public - все logins принадлежат роли public уровня сервера, все users принадлежат роли public уровня БД
	разрешения роли public наследуются всем пользователям (если нет явного DENY/GRANT)
	роль public (уровня сервера и уровня БД) не м.б. удалены

dbo Database User and Schema
	dbo - особый пользователь уровня БД, включен в роль db_owner
	SQL Server automatically maps the sa login, database owner, and members of the sysadmin server role to the dbo user account in each database 
	все администраторы SQL Server, участники роли sysadmin, логин sa и владельцы БД подключаются к базам данных в качестве пользователя dbo. можно проверить SELECT CURRENT_USER
	dbo имеет все разрешения в БД и не может быть ограничен или удален 
	dbo означает владельца БД, но уч. запись dbo не совпадает с предопределенной ролью БД db_owner; а роль БД db_owner не соответствует уч. записи владельца БД
	пользователь dbo явл. владельцем схемы dbo, эта схема не м.б. удалена. dbo - схема по умолчанию

guest Database User and Schema
	guest - user включен в каждую БД, используется если у пользователя есть доступ в БД, но нет нет уч. записи в ней.
	You can use the guest user to grant database access to logins that are not associated with user accounts in that database
	пользователя guest нельзя удалить, но можно отключить.
	Although the guest user cannot be dropped, it is disabled by default and assigned no permissions

sys Database User and Schema
	sys - user sys отключен по умолчанию (не нужен для общих задач), нельзя удалить. the user is there only to support the schema
	The database engine requires the sys schema for internal use. You cannot modify or drop the schema. It contains a number of important system objects

INFORMATION_SCHEMA Database User and Schema
	INFORMATION_SCHEMA - user отключен по умолчанию, нельзя удалить. the user is there only to support the schema
	The database engine requires the sys schema for internal use.


##... это системные имена входа (logins) на основе сертификата, нельзя удалить:
##MS_SQLResourceSigningCertificate##
##MS_SQLReplicationSigningCertificate##
##MS_SQLAuthenticatorCertificate##
##MS_AgentSigningCertificate##
##MS_PolicyEventProcessingLogin##
##MS_PolicySigningCertificate##
##MS_PolicyTsqlExecutionLogin##

Fixed Server Roles
разрешения предопределенных ролей SQL Server менять нельзя (кроме роли public)
sysadmin - любые действия на сервере
serveradmin - менять настройки конфигурации сервера, выключать сервер
securityadmin - настройки безопасности (вход на сервер, смена разрешений на сервере и БД, сброс пароля)
processadmin - можно завершать процессы на сервере
setupadmin - можно добавлять linked server используюя T-SQL
bulkadmin - можно вып. инструкцию BULK INSERT
diskadmin - управление файлами на диске
dbcreator - создание, изменение и удаление любых БД
public

Fixed Database Roles
разрешения предопределенных ролей Database менять нельзя (кроме роли public)
db_owner - любые действия по настройке БД
db_securityadmin - управление разрешениями
db_accessadmin - добавление/удаление прав удаленного доступа к БД
db_backupoperator - создание бэкапов
db_ddladmin - любые команды DDL
db_datawriter - добавлять/изменять/удалять данные в любых пользовательских таблицах
db_datareader - чтение данных из любых пользовательских таблиц
db_denydatareader - не могут добавлять/изменять/удалять данные в любых пользовательских таблицах
db_denydatawriter - не могут читать данные из любых пользовательских таблиц

для БД master:
dbmanager
loginmanager

для БД msdb:
db_ssisadmin	--службы SSIS
db_ssisoperator
db_ssisltduser
dc_admin		--служба Data Collector
dc_operator
dc_proxy
PolicyAdministratorRole
ServerGroupAdministratorRole
ServerGroupReaderRole
dbm_monitor

Application Role
участники (principals) БД, позволяющий приложению выполняться со своими, подобными пользователю, правами доступа.

Credentials (учетные данные) - запись, кот. содержит сведения для проверки подлинности, кот. необходимы для подключения к ресурсу вне SQL Server 
(например для настроек DB Mail accounts - проверка уч. записи при подключении к почтовому серверу)




Securables
SQL Server:
	SQL Server login
	Endpoint
	Database:
		Application role
		Assembly
		Assymetric key
		Certificate
		Contract
		Full-text catalog
		Message type
		Remot service binding
		Role
		Route
		Service
		Symmetric key
		User
		Schema:
			Table
			View
			Function
			Procedure
			Queue
			Synonym
			Type
			XML schema collection












Запустить SSMS под другим Windows account: ПК на значке SSMS -> Run as other account







*/


-------------------------
/*Server-Level Catalog */
-------------------------
select * from sys.server_principals
select * from sys.server_permissions
select * from sys.server_role_members
select * from sys.credentials
select * from sys.system_components_surface_area_configuration --каждый исполняемый системный объект, который может быть включен или отключен компонентом конфигурации контактной зоны (только для БД master, msdb, mssqlsystemresource)

--------------------------------
/*Database-Level Catalog Views*/
--------------------------------
select * from sys.database_principals
select * from sys.database_permissions
select * from sys.database_role_members
select * from sys.master_key_passwords
select * from sys.credentials
select * from sys.database_scoped_credentials

/*Security-Related Functions*/
select * from sys.fn_builtin_permissions(NULL)
select * from sys.fn_my_permissions(null,null)


------------------------------------
/*Encryption-Related Catalog Views*/
------------------------------------
select * from sys.certificates
select * from sys.asymmetric_keys
select * from sys.symmetric_keys
select * from sys.dm_database_encryption_keys



----------------------------------
/*Auditing-Related Catalog Views*/
----------------------------------
select * from sys.server_audits
select * from sys.database_audit_specifications
select * from sys.dm_audit_actions
select * from sys.dm_server_audit_status





/*cross-database ownership chaining*/
--server level
execute sp_configure 'show advanced', 1
reconfigure
execute sp_configure 'cross db ownership chaining', 0
reconfigure

--db level
alter database Test set db_chaining on;



