/*COLUMN STORE INDEX
<= 2008 R2: CI/Heap + NCIs, no CCI
2012:		CI/Heap + NCIs, NCCIs (но данные неизменяемы)
2014:		CCI (изменяемый, но единственный индекс на таблице) либо CI/Heap + NCIs, NCCIs (но данные неизменяемы)
2016:		CI/Heap + NCIs, NCCIs либо CCI + NCIs

2014 (CCI)
CCI реализован за счет незменяемого колоночного индекса и промежуточную структуру Delat Store (B-tree)
т.е. совместное использование Columnstore Data (CCI) и Rowstore data (CI - Delta Store)
INSERT: когда Delta Store заполняется (примерно 1млн строк), то структура закрывается фоновым процессом (Tuple Mover) и подключается к колоночному формату
DELETE: 1. удаление из Delta Store происходит напрямую
		2. удаление из Columnstore Data происходит за счет структуры Deleted Bitmap (битовая маска, кот. помечается как удаленная, но сама строка не удаляется;)
UPDATE, MERGE: раскладываются на INSERT и DELETE

2016 (NCI)
INSERT: аналогичен 2014
DELETE: удаление из базового индеса (CI/Heap) + удаление из NCI (удаление из Delta Store либо вставка в Deleted Buffer).
После того как в Deleted Buffer наберется более 1млн строк в фоновом процессе данные добавятся в Deleted Bitmap

2016 (CCI)
INSERT: аналогичен 2014
DELETE: аналогичен 2014

Целостность данных (т.е. связь между строками в NCI и основной таблицей в виде CCI) поддерживается с помощью структуры Internal Mapping Index (одна на все индексы),
которая обеспечивает связь между строками для операций KeyLookup и удаления данных в NCI при удаления строки из таблицы.

CCI - в основном используются для data warehouse (fact table)
NCI - в основном используются для real-time аналитики в OLTP-системах
*/



--просмотр внутренних объектов для колоночного индекса (Deleted Buffer, Deleted Bitmap)
select * from sys.internal_partitions 

select * from sys.column_store_segments
select * from sys.column_store_row_groups



--------------------------------------------------------------------------------------------
------------------------------------------Maintaince----------------------------------------
--------------------------------------------------------------------------------------------

SELECT count(*) FROM [TEST].[dbo].[PeopleNN]
select top 10 * from [TEST].[dbo].[PeopleNN]

--создание NCCI
create nonclustered columnstore index NCCI_peoplenn_col on [PeopleNN] (id, cityid)

--удаление NCCI
drop index NCCI_peoplenn_col on [PeopleNN]

--создание CCI
create nonclustered columnstore index CCI_peoplenn_col on [PeopleNN](id)

--перестроение
alter index CCI_peoplenn_col reorganize with (compress_all_row_groups = on)


/*режим Batch Mode
можно использовать только при наличии колоночного индекса

можно сделать пустой NCCI (т.е. фильтруемый с вырожденным условием) и включить режим Batch 

*/
--см теорию
