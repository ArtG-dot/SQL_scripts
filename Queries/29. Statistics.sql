/*
Статистика - это сведения о распределении значений в конкретном столбце таблицы
статистика отражает распределение данных в индексе в виде гистограммы
	гистограмма строится только по ОТДЕЛЬНОМУ столбцу таблицы
	гистограмма строится только по левому столбцу составного ключа индекса

Статистика создается: при создании индекса (в том числе и REBUILD), автоматически при запросе (для каждого столбца в условии where), вручную

статистика обновляется автоматически для таблицы если
1. в пустую таблицудобавили записи
2. в таблице было менее 500 записей и изменилось более 500 записей
3. в таблице было более 500 записей и изменяется 20% строк + 500: (менятся может только 1 строка, но более 20% + 500 раз)
например если в таблице 1500 строк и мы выполняем insert (1500*20/100 + 500 - 1) = 799 строк, то статистика не перестраивается
если встяавляем еще 1 строку, то статистика обновляется

*/

select * from sys.stats s 
select * from sys.stats_columns c


trace flag 2371
изменяет условие пересчета 
!!! тестировать перед применением


--свойства статистики
select * from sys.dm_db_stats_properties(OBJECT_ID('test'),1) --object_id, stats_id



/*создание статистики*/
--1. Автоматическое при создании индекса (
--2. Автоматическое, если серверу необходима информация по распределению значений в столбце/ах (обозначается _WA_Sys_...)
--3. Вручную 
create statistics ST_temp1_val on tabl(val)
	with FULLSCAN --полное сканирование таблицы
	with SAMPLE 25 PERCENT --сканирование 25% строк
	with SAMPLE 1000 ROWS --сканирование 1000 строк

/*создание фильтруемой статистики
создается несколько объектов статистики в зависимости от конкретного значения столбца, 
это может обеспечить корректное оценочное число строк при создании плана запроса

аналогично создается при фильтруемом индексе
*/
CREATE STATISTICS MyRegionTable_stats_id ON MyRegionTable (id) 
WHERE Location = 'Atlanta' 
GO 
CREATE STATISTICS MyRegionTable_stats_id2 ON MyRegionTable (id) 
WHERE Location = 'San Francisco' 
GO




/*обновление статистики*/
update statistics dbo.temp1 (ST_temp1_val)
	with fullscan
	with sample 10 percent
	with index, norecompute
	with incremental = on --used with partition



/*удаление статистики*/
drop statistics dbo.temp1.[tt.ST_temp1_val]
--можно нескотльких сразу
drop statistics dbo.temp1.[tt.ST_temp1_val], dbo.temp1.[tt.ST_temp1_val2]



/*
гистограмма (не более 200 шагов):
RANGE_HI_KEY - верхнее значение ключа для шага гистограммы
RANGE_ROWS - предполагиемое кол-во строк в пределах шага (исключая верхнюю границу)
EQ_ROWS - предполагиемое кол-во строк, значение кот. равно верхней границы шага (RANGE_HI_KEY)
DISTINCT_RANGE_ROWS - предполагиемое кол-во строк с разным значением столбца в пределах шага (исключая верхнюю границу)
AVG_RANGE_ROWS - среднее кол-во строк с повторяющимся значением столбца в пределах шага (исключая верхнюю границу)

*/
DBCC SHOW_STATISTICS('Sales.SalesTerritoryHistory','AK_SalesTerritoryHistory_rowguid')

DBCC SHOW_STATISTICS('Sales.SalesTerritoryHistory','AK_SalesTerritoryHistory_rowguid')
	with stat_header --заголовок (density - % уникальных значений)
	with density_vector --информация по плотности (1/(кол-во уникальных записей)) для комбинаций полей
	with histogram --гистограмма
	with stats_stream



