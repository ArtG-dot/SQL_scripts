--------------------------
/*Temporal Tables (2016)*/
--------------------------
/*system-versioned temporal tables позволяют отслеживать изменения в таблице во времени,
т.е. хранят историчекую информацию для строк, можно посмотреть какая информация была в таблице (срез) в любой момент времени
должна содержать 2 поля с типом datetime2, эти поля используются системой для отражения "периода актуальности" строки 
	даты в формате UTC time zone (!!!)
	ValidTo = 9999-12-31 23:59:59.99 означает, что строка актуальна
есть ссылка на history table, в которой хранятся предыдущие версии строк (history table - старые версии строк, temporal table - актуальные версии строк
	имя для history table можноне указывать явно, тогда имя будет присвоено автоматически 
*/

--1. создаем temporal table
create table tt (
	id int identity(1,1) primary key --ограничение PK обязательно
	, val char(5)
	, ValidFrom	datetime2 (2) GENERATED ALWAYS AS ROW START --доп. поле
	, ValidTo	datetime2 (2) GENERATED ALWAYS AS ROW END	--доп. поле
	, PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
) WITH (SYSTEM_VERSIONING = ON
		(HISTORY_TABLE = dbo.tt_history));

select * from sys.tables where temporal_type != 0

--2. заполняем таблицу
insert into tt(val) values ('aaa'),('bbb'),('ccc')

select * from tt
select * from tt_history

--3. меняем данные в таблице
insert into tt(val) values ('zzz')
select * from tt --новая запись
select * from tt_history 

update tt set val = 'sss' where val = 'bbb'
select * from tt --поле ValidFrom поменялось 
select * from tt_history --новая запись

delete tt where val = 'ccc'
select * from tt -- минус строка
select * from tt_history --новая запись

--4. для вывода всех изменений данных
select * from tt --актуальные данные в таблице
--4.1. объединенные (UNION) данные из temporal table и history table
select * from tt FOR SYSTEM_TIME ALL order by 1

--4.2. срез данных, актуальных на момент времени
select * from tt FOR SYSTEM_TIME AS OF '2019-09-05 08:55:38.00'
select * from tt FOR SYSTEM_TIME AS OF '2019-09-05 08:55:39.00' --разница в секунду, но данные разные

--4.3. все строки которые были активными в указанный промежуток (включая границы, >=, <=)
select * from tt FOR SYSTEM_TIME BETWEEN '2019-09-04 00:00:00' and '2019-09-05 09:03:31.16'
	where val != 'aaa' order by 1

--4.4. все строки которые были активными в указанный промежуток (за исключением границ, >, <)
select * from tt FOR SYSTEM_TIME FROM '2019-09-04 00:00:00' TO '2019-09-05 09:03:31.16'
	where val != 'aaa' order by 1

--4.5. строки, которые были открыты или закрыты в указанные приод (включая границы, >=, <=)
select * from tt FOR SYSTEM_TIME CONTAINED IN ('2019-09-05 08:55:38.37','9999-12-31 23:59:59.99')
	where val != 'aaa' order by 1

--5. Удаляем таблицу
ALTER TABLE [dbo].[tt] SET (SYSTEM_VERSIONING = OFF) --отключим версионность
DROP TABLE [dbo].[tt] --удаляем temporal table
DROP TABLE [dbo].[MSSQL_TemporalHistoryFor_197067938] --удаляем history table