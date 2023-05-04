-----------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------

set statistics time on 
------------------------------------------
/*парсинг строки по колическву символов*/
------------------------------------------

--1. Одиночная строка/переменная
	--создаем функцию
	create --drop 
	function fn_StrParsNumTsql
		(@str nvarchar(4000)
		, @n int)
	returns @tbl table 
		(substr nvarchar(4000), poz int)
	as 
	begin	
			with cte (str_len, cnt) as (
				select len(@str) str_len, 1 cnt
				union all
				select  str_len - @n str_len, cnt + 1 
				from cte
				where str_len > @n
			)
			insert into @tbl
				select SUBSTRING(@str, (cnt - 1)*@n + 1, @n), cnt
				from cte;
		return
	end


	/*
		begin	
			with cte as (
				select len(@str) str_len, 1 len_d
				union all
				select  str_len - @n str_len, len_d + 1 
				from cte
				where str_len > @n
			)
			insert into @tbl
				select SUBSTRING(@str, (len_d - 1)*@n + 1, @n), len_d
				from cte;
		return
	*/


	--проверяем для переменной (для таблицы нужно исп APPLY)
	declare @str nvarchar(50) = '0123456789';
	declare @n int  = 3; --длина подстроки
	select @str, * from fn_StrParsNumTsql(@str,@n);

	--для таблицы типа того
	select st, g.* from #ttt
	outer apply (select * from fn_StrParsNumTsql(st,4)) g

-----------------------------------------------------------------------------------------------------------------------------------------------------
--2. Обработка большого кол-ва строк
	--создаем таблицы
	drop table if exists #temp, #ttt;

	create table #temp (st nvarchar(2000));
	insert into #temp values ('B024CA01CA06M031'), ('B029CA84CA55M085B099df89'),(''),('B024CA06M031'),('B024CA06M031B024CA06M031')

	create table #ttt (st nvarchar(4000));

	insert into #ttt --максимумм около 10 млн строк
		select top 10000 CONCAT(t1.st, t2.st, t3.st, t4.st, t5.st, t6.st, t7.st, t8.st, t9.st, t10.st) from #temp t1
		cross join #temp t2
		cross join #temp t3
		cross join #temp t4
		cross join #temp t5
		cross join #temp t6
		cross join #temp t7
		cross join #temp t8
		cross join #temp t9
		cross join #temp t10

	--a. парсинг через CTE
	declare @n int = 3; --длина подстроки

	; with cte (str_v, str_len, str_cnt, str_num) as (
		select st, len(st) str_len, 1, ROW_NUMBER() over (order by st) from #ttt
		union all
		select str_v, str_len - @n, str_cnt + 1, str_num  from cte
		where str_len > @n
	)
	select str_v, SUBSTRING(str_v, (str_cnt - 1) * @n + 1, @n), str_cnt, str_num 
	from cte
	--where cnt > 0
	--order by str_num, str_cnt

	--b. парсинг через функцию
	declare @n int = 3; --длина подстроки

	--нужно определить поля для сортировки
	select t.st str_v, a.substr, a.poz str_cnt
	from #ttt t
	cross apply (select * from fn_StrParsNumTsql(st, @n)) a
	--order by str_v, str_cnt

	select t.st str_v, a.substr, a.poz str_cnt, t.str_num
	from (select st, ROW_NUMBER() over (order by (select null)) str_num from #ttt) t
	cross apply (select * from fn_StrParsNumTsql(st, @n)) a
	order by str_num, str_cnt

-----------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------
/*парсинг строки по символу-разделителю*/
------------------------------------------

--1. Одиночная строка/переменная
	--a. для 2016 и старше 
	declare @str1 nvarchar(2000) =  N'7смсe30;7e36;6смсe29;5le26;5e28;';
	declare @div1 nvarchar(5) = N';';

	select * from STRING_SPLIT(@str1, @div1)
	where value <> ''; --убираем пустые строки

	--для таблицы типа того
	select st, g.* from #ttt r
	outer apply (select * from STRING_SPLIT(r.st,';')) g


	--b. для любой версии (самый быстрый, но надо тестить)
	declare @str2 nvarchar(2000) =  N'7смсe30;7e36;6смсe29;5le26;5e28;';
	declare @div2 nvarchar(5) = N';';

	; with cte as ( 
		select @str2 r , 1 as x, charindex(@div2,@str2) c, substring(@str2,1,charindex(@div2,@str2)-1) t 
		union all 
		select r , x + 1 , charindex(@div2,@str2,c+1) , substring(@str2,c + 1, charindex(@div2,@str2,c+1) - c - 1)  
		from cte where  x < len(@str2) - len (replace(@str2,@div2,'')) 
	) 
	select r,t from cte  
 

	 --c. для любой версии
	declare @str3 varchar(100) = '7смсe30;7e36;6смсe29;5le26;5e28;'
	declare @div3 varchar(5) = ';'

	; with cte (a,b,c) as (
		select 1, 1, CHARINDEX(@div3, @str3,1)
		union all
		select a+1, c+1, CHARINDEX(@div3, @str3,c+1) from cte
		where c != 0
		)
	select a, SUBSTRING(@str3, b, case when c> 0 then c-b else len(@str3) end) g from cte
	

	--d. для любой версии (самый медленный, но надо тестить)
	declare @str4 varchar(100) = '7смсe30;7e36;6смсe29;5le26;5e28;'
	declare @div4 varchar(5) = ';'

	select *
	from (select @str4 v, cast('<r><c>' + replace (@str4,';','</c><c>')+'</c></r>' as xml) s) t 
	cross apply (select x.z.value('.','nvarchar(200)') v from s.nodes ('/r/c') x(z))tt 
	where tt.v != ''


-----------------------------------------------------------------------------------------------------------------------------------------------------

--2. Обработка большого кол-ва строк
	--создаем таблицы
	drop table if exists #temp, #ttt;

	create table #temp (st varchar(100));
	insert into #temp values ('7смсe30;7e36;6смсe29;5le26;5e28;'), ('7смсe30;7e36;6смсe29;5le26;5e28;7смсe30;7e36;6смсe29;5le26;5e28;'),(''),('7смсe30;7e36;6смсe29;'),('7смсe30;7e36;6смсe29;5le26;5e28;')

	create table #ttt (st varchar(8000));

	insert into #ttt
		select top 100000 CONCAT(t1.st, t2.st, t3.st, t4.st, t5.st, t6.st, t7.st, t8.st, t9.st, t10.st) from #temp t1
		cross join #temp t2
		cross join #temp t3
		cross join #temp t4
		cross join #temp t5
		cross join #temp t6
		cross join #temp t7
		cross join #temp t8
		cross join #temp t9
		cross join #temp t10

	--a. через XML (самый медленный, но надо тестить)
	select *
	from (select st, cast('<r><c>' + replace (st,';','</c><c>')+'</c></r>' as xml) s from #ttt) t
	cross apply (select x.z.value('.','nvarchar(200)') v from s.nodes ('/r/c') x(z)) tt  --для x.z.value нужно указывать корректный тип данных
	where tt.v != ''


	--b. черех CTE (быстрый, но надо тестить)
	declare @div nvarchar(5) = N';';

	; with cte (st,a,b,c, rn) as (
		select st, 1, 1, CHARINDEX(@div, st, 1), ROW_NUMBER() over (order by st) rn from #ttt
		union all
		select st, a+1, c+1, CHARINDEX(@div, st, c+1), rn from cte
		where c != 0
		)
	select st, SUBSTRING(st, b, case when c> 0 then c-b else len(st) end) g , a,  rn  
	from cte
	where SUBSTRING(st, b, case when c> 0 then c-b else len(st) end) <> ''
	order by rn, a






































create table #temp (client_id varchar(10));
go
truncate table #temp;
insert into #temp
values 
('3688'),
('7182'),
('1926'),
('0195'),
('8400'),
('4911'),
('8007'),
('5659'),
('2233'),
('3296'),
('1392'),
('7035'),
('1323'),
('5255');
go
select * from #temp;

set nocount on;
declare @str_num varchar(20),@str_like varchar(20);
declare cur cursor
	for select client_id from #temp;
open cur;
fetch next from cur into @str_num;
set @str_like = '%' + @str_num + '%';
while @@FETCH_STATUS = 0
begin
	delete from ap_storage 
	where DATA like @str_like
	and ATTEMP_STATE != 1; 
	print 'select ' + @str_like + ' has done!'
	fetch next from cur into @str_num;
	set @str_like = '%' + @str_num + '%';
end;
close cur;
deallocate cur; 


