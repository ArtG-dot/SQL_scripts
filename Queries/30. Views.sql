drop table if exists tab_1;
drop table if exists tab_2;
drop view if exists view_1;
drop view if exists view_2;

create table tab_1 (id int, value varchar(255));
create table tab_2 (id int, value varchar(255));

create table #tab (num int);
insert into #tab values (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

insert into tab_1
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

insert into tab_2
select 
t6.num * 100000 +
t5.num * 10000 +
t4.num * 1000 +
t3.num * 100 +
t2.num * 10 +
t1.num + 1 num
, 'bbb' val
from #tab t1
cross join #tab t2
cross join #tab t3
cross join #tab t4
cross join #tab t5
cross join #tab t6

create view view_1
as
select 'tab1' nm_tab,
id, value
from tab_1
union all
select 'tab2',
id, value
from tab_2

select * from view_1 where nm_tab = 'tab1' --SQL server will scan only tab_1 table (!!!), tab_2 will not be scanned

create view view_2
as
select id, value from tab_1
union all
select id, value from tab_2

select * from view_2 where value = 'aaa' --both tables will be scanned

