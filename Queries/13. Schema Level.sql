/*все объекты в БД имеют владельца
Косвенно владелец наследуется от схемы

Каждая БД содержит схему dbo и юзера dbo. Не нужно их путать.
SQL Server automatically maps the sa login, database owner, and members of the sysadmin server role to the dbo user account in each database.
The dbo user also owns the dbo schema



When you create a user, you can specify a default schema. If you do not, the dbo schema is assumed. 
If you specify a default schema other than dbo and the user is a member of the sysadmin server role, 
the specified schema is ignored and the dbo schema is used. The default schema for all members of sysadmin is dbo.


Every database contains a dbo user and dbo schema.		The dbo user owns the dbo schema.		
Every database contains a guest user and guest schema.	The guest user owns the guest schema.
Every database contains a sys user and sys schema.		The sys user owns the sys schema.
*/


--просмотр владельцев схем
SELECT  
    [name] AS [schema]  
  , [schema_id] 
  , USER_NAME(principal_id) [Owner] --это principal из 
FROM sys.schemas;

			select * from sys.database_principals

-------------------------------
/*создание схемы для объектов*/
-------------------------------
create schema myNewShm authorization dbo;

		--удаление схемы
		drop schema myNewShm

--изменение владельца схемы
alter authorization on schem::myNewShm to user_nm
select SCHEMA_NAME, SCHEMA_OWNER from INFORMATION_SCHEMA.SCHEMATA


--изменение владельца объекта
CREATE USER TestUser WITHOUT LOGIN; 
CREATE TABLE Marketing.OwnedTable ( 
  TableValue INT 
); 
GO 

ALTER AUTHORIZATION ON Marketing.OwnedTable TO TestUser; 


SELECT  
    so.[name] AS [Object] 
  , sch.[name] AS [Schema] 
  , USER_NAME(COALESCE(so.[principal_id], sch.[principal_id])) AS [Owner] 
  , type_desc AS [ObjectType] 
FROM sys.objects so 
  JOIN sys.schemas sch 
    ON so.[schema_id] = sch.[schema_id] 
WHERE [type] IN ('U', 'P');



/*права для пользователя*/
grant select on [dbo].[overview] to [domain\user]
grant select on [dbo].[overview] to myRole
grant insert on buffer.dbo.table1 to currency_upload_login
grant alter on buffer.dbo.table1 to currency_upload_login

grant create table to [domain\user]
grant alter on schema::dbo to [domain\user]

grant EXECUTE on [dbo].table2 to [domain\user]



------------------------------------
/*цепочка владения для одной схемы*/
------------------------------------
--создаем тестовых юзеров
drop user if exists u1;
drop user if exists u2;  --мы не можем удалить юзера, если от его имени идет запуск ХП (with exec as self), сначало удалим ХП
drop user if exists u3;
create user u1 without login;
create user u2 without login;
create user u3 without login;

--для u1 разрешаем создавать таблицы, заполнять м получать данные
grant alter on schema::dbo to u1
grant create table to u1
grant insert to u1
grant select to u1

--от имени u1 создадим таблицу 
execute as user = 'u1'
	select USER_NAME()
	drop table if exists t1;
	create table t1 (id int identity, val varchar(10));
	insert into t1 values ('a'), ('b'), ('c')
	select * from t1;
revert
select USER_NAME()

--для u2 разрешаем создавать ХП, но запретим получать данные из таблиц
deny select to u2
grant alter on schema::dbo to u2
grant create view to u2

--от имени u2 создадим ХП с получением данных из этой таблицы 
execute as user = 'u2'
	select USER_NAME()

	select * from t1; --запрет

	drop proc if exists p_u2; 

	create proc p_u2 
	--with exec as caller --вызов ХП от имени запустившего exec sp_name
	--with exec as self --запуск от имени создателя ХП (u2)
	--with exec as owner --это владелец схемы (dbo),  у u2 нет прав на авторизацию ХП для dbo
	with exec as 'u3'
	as begin
		select USER_NAME()
		select * from t1;
	end;

revert
select USER_NAME()

exec p_u2

--для u3 разрешаем запуск ХП, но запретим получать данные из таблиц
grant exec to u3
deny select to u3

--от имени u3 запустим ХП
execute as user = 'u3'
	select USER_NAME()

	select * from t1; --запрет

	exec p_u2 --все ок
revert
select USER_NAME()

/*Вывод:
в рамках одной схемы создатель ХП может не иметь доступ к объектам, к которым идут запросы
если у пользователя есть разрешение на запуск ХП, она будет исполнена

*/

sp_changeobjectowner 'guest.t1', 'dbo'
select * from sys.database_principals

public
dbo
guest
INFORMATION_SCHEMA
sys
loginless_user
u1
u2
u3





-------------------------------------------------------------------------------------------------------------------------------------

------------------------------------
/*цепочка владения для одной схемы*/
------------------------------------
--создаем тестовых юзеров
drop user if exists u1;
drop user if exists u2;  --мы не можем удалить юзера, если от его имени идет запуск ХП (with exec as self), сначало удалим ХП
drop user if exists u3;
create user u1 without login;
create user u2 without login;
create user u3 without login;

--для u1 разрешаем создавать таблицы, заполнять м получать данные
grant alter on schema::dbo to u1
grant create table to u1
grant insert to u1
grant select to u1

--от имени u1 создадим таблицу 
execute as user = 'u1'
	select USER_NAME()
	drop table if exists t1;
	create table t1 (id int identity, val varchar(10));
	insert into t1 values ('a'), ('b'), ('c')
	select * from t1;
revert
select USER_NAME()

--для u2 разрешаем создавать ХП, но запретим получать данные из таблиц
deny select to u2
grant alter on schema::dbo to u2
grant create view to u2

--от имени u2 создадим ХП с получением данных из этой таблицы 
execute as user = 'u2'
	select USER_NAME()

	select * from t1; --запрет
	select * from v_u2
	drop view if exists v_u2; 

	create view v_u2 
	as 
		select * from t1;


revert
select USER_NAME()
select * from t1
select * from v_u2

--для u3 разрешаем запуск ХП, но запретим получать данные из таблиц
grant select on v_u2 to u3


--от имени u3 запустим ХП
execute as user = 'u3'
	select USER_NAME()

	select * from t1; --запрет

	select * from v_u2 --все ок
revert
select USER_NAME()

/*Вывод:
в рамках одной схемы создатель ХП может не иметь доступ к объектам, к которым идут запросы
если у пользователя есть разрешение на запуск ХП, она будет исполнена

*/

sp_changeobjectowner 'guest.t1', 'dbo'
select * from sys.database_principals

public
dbo
guest
INFORMATION_SCHEMA
sys
loginless_user
u1
u2
u3
