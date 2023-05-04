--------------------------------------------------------
/*генерация большого объема данных по скорости вставки*/
--------------------------------------------------------
--тестирование проходило на домашнем ноуте
--!!!наилучший результат 3.2!!! нужно перепроверить
--правка: наилучший результат через native compiled SP (см скрипты для in-memory table)

set statistics io off;
set statistics time on;

--вариант 1 (очень плохой, не использовать)
--изменяя кол-во пакетов (100 000 за 1м 17с)
create table #temp (id int identity, val varchar(20));

insert into #temp(val) values ('aaa')
go 100000

drop table #temp;


--вариант 2 (плохой, не использовать)
--с помощью цикла (100 000 за 0м 18с, 1 000 000 за 4м 01с)
create table #temp (id int identity, val varchar(20));

declare @i int = 0;
while @i < 1000000
begin
	set @i += 1;
	insert into #temp(val) values ('aaa');
	--insert into #temp(id, val) values (@i,'aaa');
end 

drop table #temp;


--вариант 3 (используя вспомогательную таблицу)
--вариант 3.1 
--с помощью CROSS JOIN и SELECT INTO (100 000 за 0м 1с, 1 000 000 за 0м 4с)
--CPU 2400 ms, elapsed 700 ms
create table #tab (num int);
insert into #tab values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

select 
t6.num * 100000 +
t5.num * 10000 +
t4.num * 1000 +
t3.num * 100 +
t2.num * 10 +
t1.num + 1 num
, 'aaa' val
into #temp
from #tab t1
cross join #tab t2
cross join #tab t3
cross join #tab t4
cross join #tab t5
cross join #tab t6
--order by num	--сортировка не дает упорядоченную вставку, разница в производительности на уровне погрешности

drop table #temp;
drop table #tab;


--вариант 3.2
--с помощью CROSS JOIN и INSERT SELECT (100 000 за 0м 1с, 1 000 000 за 0м 4с)
--CPU 1000 ms, elapsed 1000 ms
create table #tab (num int);
insert into #tab values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

create table #temp (id int, val varchar(20));

insert into #temp(id, val)
	select 
	t6.num * 100000 +
	t5.num * 10000 +
	t4.num * 1000 +
	t3.num * 100 +
	t2.num * 10 +
	t1.num + 1 num
	, 'aaa' val
	from #tab t1
	cross join #tab t2
	cross join #tab t3
	cross join #tab t4
	cross join #tab t5
	cross join #tab t6
	--order by num	--сортировка не дает упорядоченную вставку, разница в производительности на уровне погрешности


drop table #temp;
drop table #tab;


--вариант 3.3
--с помощью CROSS JOIN и INSERT SELECT + св-во IDENTITY (100 000 за 0м 1с, 1 000 000 за 0м 4с)
--CPU 1400 ms, elapsed 900 ms
create table #tab (num int);
insert into #tab values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

create table #temp (id int identity, val varchar(20));

insert into #temp(val)
	select 
	'aaa' val
	from #tab t1
	cross join #tab t2
	cross join #tab t3
	cross join #tab t4
	cross join #tab t5
	cross join #tab t6

drop table #temp;
drop table #tab;


--вариант 4 (используя CTE)
--вариант 4.1
--с помощью CTE + CROSS JOIN и INSERT SELECT
--CPU 600 ms, elapsed 1300 ms
create table #temp (id int, val varchar(20));

; with cte as (select * from (values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) t(num))
, cte1 as (
	select 
	t6.num * 100000 +
	t5.num * 10000 +
	t4.num * 1000 +
	t3.num * 100 +
	t2.num * 10 +
	t1.num + 1 num
	, 'aaa' val
	from cte t1
	cross join cte t2
	cross join cte t3
	cross join cte t4
	cross join cte t5
	cross join cte t6)
insert into #temp
	select num, val from cte1
	--order by num	--сортировка не дает упорядоченную вставку, разница в производительности на уровне погрешности

drop table #temp;


--вариант 4.2
--с помощью CTE + CROSS JOIN и INSERT SELECT + св-во IDENTITY
--CPU 700 ms, elapsed 1300 ms
create table #temp (id int identity, val varchar(20));

; with cte as (select * from (values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) t(num))
, cte1 as (
	select 
	t6.num * 100000 +
	t5.num * 10000 +
	t4.num * 1000 +
	t3.num * 100 +
	t2.num * 10 +
	t1.num + 1 num
	, 'aaa' val
	from cte t1
	cross join cte t2
	cross join cte t3
	cross join cte t4
	cross join cte t5
	cross join cte t6)
insert into #temp(val)
select val from cte1

drop table #temp;


--вариант 4.3
--с помощью рекурсивного CTE (100 000 за 0м 2с, 1 000 000 за 0м 20с)

;with CTE(id,val)
as
(
   select 1, 'aaa'
   union all
   select id + 1, val from CTE where ID < 1000000
)
select id, val 
into #temp
from CTE
option (maxrecursion 0);

drop table #temp;



-----------------------------------------------------------
/*генерация случайных значений данных по скорости вставки*/
-----------------------------------------------------------
select newid() [uid]
	, RAND() [0-1]
	, checksum(newid())
	, rand(checksum(newid())) [0-1]
	, rand(checksum(newid()))*100 [0-100] --нецелое
	, cast(rand(checksum(newid()))*100 as int) [0-100] --целое
	, cast(RAND()*100 as int) [0-100] --целое
	

/*задача:
сгенерировать 1 000 000 записей со случаймым целым значением от 0 до 100 */
--варианты 1 и 2 показали одинаковый результат
--нужно проверить на бќльших объемах, возможно вариант 2 более производительный

--вариант 1
create table #tab (num int);
insert into #tab values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);
create table #temp (id int, val int); 

insert into #temp(id, val)
	select 
	t6.num * 100000 +
	t5.num * 10000 +
	t4.num * 1000 +
	t3.num * 100 +
	t2.num * 10 +
	t1.num + 1num
	, cast(rand(checksum(newid()))*100 as int) val
	from #tab t1
	cross join #tab t2
	cross join #tab t3
	cross join #tab t4
	cross join #tab t5
	cross join #tab t6
	order by num

drop table #temp;
drop table #tab;

select top 100 * from #temp;
select val, count(*) cnt from #temp group by val order by val


--вариант 2
create table #tab (num int);
insert into #tab values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);
create table #temp (id int, val int default cast(rand(checksum(newid()))*100 as int)); 

insert into #temp(id)
	select 
	t6.num * 100000 +
	t5.num * 10000 +
	t4.num * 1000 +
	t3.num * 100 +
	t2.num * 10 +
	t1.num + 1num
	from #tab t1
	cross join #tab t2
	cross join #tab t3
	cross join #tab t4
	cross join #tab t5
	cross join #tab t6
	order by num

drop table #temp;
drop table #tab;

select top 100 * from #temp;
select val, count(*) cnt from #temp group by val order by val










------------------------------------------------------------------------

select @@IDENTITY, SCOPE_IDENTITY();
dbcc checkident('temp6',reseed,10);
select @@IDENTITY, SCOPE_IDENTITY();


------------------------------------------------------------------------
USE SlowLogFile;
GO
SET NOCOUNT ON;
WHILE (1=1)
BEGIN
	INSERT INTO BadKeyTable DEFAULT VALUES;
END;
GO

------------------------------------------------------------------------

with N1(C) as (select 0 union all select 0) -- 2 rows
,N2(C) as (select 0 from N1 as T1 CROSS JOIN N1 as T2) -- 4 rows
,N3(C) as (select 0 from N2 as T1 CROSS JOIN N2 as T2) -- 16 rows
,N4(C) as (select 0 from N3 as T1 CROSS JOIN N3 as T2) -- 256 rows
,N5(C) as (select 0 from N4 as T1 CROSS JOIN N4 as T2) -- 65,536 rows
,IDs(ID) as (select row_number() over (order by (select NULL)) from N5)
insert into dbo.SARGDemo(VarcharKey)
	select convert(varchar(10),ID)
	from IDs
go


------------------------------------------------------------------------

WITH N1(C) AS (SELECT 0 UNION ALL SELECT 0) -- 2 rows
,N2(C) AS (SELECT 0 FROM N1 AS T1 CROSS JOIN N1 AS T2) -- 4 rows
,N3(C) AS (SELECT 0 FROM N2 AS T1 CROSS JOIN N2 AS T2) -- 16 rows
,N4(C) AS (SELECT 0 FROM N3 AS T1 CROSS JOIN N3 AS T2) -- 256 rows
,N5(C) AS (SELECT 0 FROM N4 AS T1 CROSS JOIN N4 AS T2) -- 65,536 rows
,N6(C) AS (SELECT 0 FROM N5 AS T1 CROSS JOIN N2 AS T2 CROSS JOIN N1 AS T3) -- 524,288 rows
,IDs(ID) AS (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM N6)
INSERT INTO dbo.Orders(ID,OrderDate,DateModified)
	SELECT  
	   ID, 
	   DATEADD(second,35 * ID,@StartDate),
	   CASE 
		  WHEN ID % 10 = 0 
		  THEN DATEADD(second,   
				24 * 60 * 60 * (ID % 31) + 11200 + ID % 59 + 35 * ID,
				@StartDate)
		  ELSE DATEADD(second,35 * ID,@StartDate)
	   END
	FROM IDs
go
