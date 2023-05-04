drop table #temp
create table #temp (id int, s varchar(5))

insert #temp values 
(1,'a'),
(2,'b'),
(3,'c'),
(3,'c'),
(4,'d'),
(4,'d'),
(4,'d');
go 1000

--1. используя CTE
; with cte as (
select id, s, ROW_NUMBER() over (partition by id, s order by id) rn from #temp
)
delete from cte
where rn > 1;

select * from #temp;

--2. используя временную таблицу (более быстрый(?))
drop table #t
select distinct * into #t from #temp;
truncate table #temp;
insert #temp select * from #t;

select * from #temp;

