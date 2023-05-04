---------------------
/*случайная выборка*/
---------------------


--выбрем случайным образом х строк 
--вариант 1
select top 3 *
from [dbo].[ttt]
order by NEWID()

--выбрем случайным образом 1 строку
--вариант 2
--вместо count(*) можно обратиться к DMV
select * from [dbo].[ttt]
where IntVal = (select ceiling(count(*)*rand()) from [dbo].[ttt]) --нужно чтобы на поле был индекс, и не было

--вариант 3
--вместо count(*) можно обратиться к DMV
select top 1 * from [dbo].[ttt]
where IntVal >= (select ceiling(max(IntVal)*rand()) from [dbo].[ttt]) --нужно чтобы на поле был индекс, и не было

--вариант 4
--может быть возврат 0 строк, для этого ставим поболеше строк в tablesample
select top 1 * from [dbo].[ttt] tablesample (100 rows) --поднимаем с диска случайную страницу
order by NEWID()




-----------------------
/*нахождение среднего*/
-----------------------
--среднее арифметическое
select avg(IntVal), sum(IntVal)/count(*) from [dbo].[ttt]

--мода (значение, кот. встречается чаще всего) (моды может не быть, мод может быть несколько)
select IntVal
from [dbo].[ttt]
group by IntVal
having count(*) >= (
					select count(*)
					from [dbo].[ttt]
					group by IntVal
					)

select top 1 with ties IntVal
from [dbo].[ttt]
group by IntVal
order by count(*) desc

--медиана (делит массив на 2 половины)
; with t as (select IntVal
			, ROW_NUMBER() over (order by IntVal asc) n1
			, ROW_NUMBER() over (order by IntVal desc) n2
			from [dbo].[ttt])
select avg(IntVal)
from t 
where abs(n1-n2)<=1


; with t as (select IntVal
			, ROW_NUMBER() over (order by IntVal asc) n1
			from [dbo].[ttt])
select avg(IntVal)
from t 
where n1 in (select ceiling(count(*)/2.0) from [dbo].[ttt]
			union all
			select ceiling(count(*)/2.0 + 1) from [dbo].[ttt])


select PERCENTILE_CONT(0.5) within group (order by IntVal) over() 
from [dbo].[ttt]

