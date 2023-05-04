/*
SP (store procedure): can change data, can return values
improving security:	different levels of access for differrent users, control access	to uderlying data and structure


*/

-------------------------------------------------------------------------------------------------------------------------------------------
drop proc if exists test_sp;
go

set nocount off --все настройки SET нужно указывать до создания/изменения ХП в отдельном пакете
go

create or alter proc test_sp ( --c 2016
	@a int --входной параметр, не меняет значение параметра
	, @b int output --входной/выходной параметр, позволяет менять значение параметра
)
as begin
	set  nocount on; --чтобы не было лишней информации о кол-ве обработанных строк 
	select @a + @b result;
	print cast(@a as varchar(10)) + ' + ' + cast(@b as varchar(10)) + ' = ' + cast(@a+@b as varchar(10));
	--set @b += @a;
	set @a = -1;
	set @b = -1;
	return 99; --после этого ХП прекращает работу
	select 'this text is not visible'
end
go

--запуск ХП
declare @ret int --для возврата кода результата ХП
declare @param1 int = 2;
declare @param2 int = 3; --параматр @b, в него запишем результат
exec @ret = test_sp @param1, @param2 output -- @ret - код возврата ХП, @sum - результат вычисления
select @ret error_code, @param1 a,  @param2 b

-------------------------------------------------------------------------------------------------------------------------------------------

/*ХП для работы с курсором*/
drop proc if exists test_curs_sp;
go

create proc test_curs_sp (@cur cursor varying output)
as begin
	set @cur = cursor for
		select c1
		from t1
		order by c1

	open @cur
end;

--создаем курсор и заполняем его через запуск ХП
declare @mycursor cursor;
declare @prm int;

exec test_curs_sp @cur = @mycursor output;

fetch next from @mycursor into @prm;
--дальше работа как с обычным курсором
select @prm
close @mycursor;
deallocate @mycursor;




-----------------------
/*CLR Store Procedure*/
-----------------------
--нельзя удалить сорку если к ней привязаны объекты
drop proc if exists my_clr_proc

--ВАЖНО!!! имя класса и метода регистрочувствительны
create proc	my_clr_proc
	as external name CLR_Test.MySprocs.Insert_Test --[Имя сборки].[Имя класса].[Имя метода]

--1 step
sp_configure 'clr enabled', 1
go
reconfigure
go

--2 step: add assemble

--3 step
create proc clr_sp
as 
external name helloworld.helloworldproc.hello --assemble.class.method
go

exec clr_sp


select * from t1
exec my_clr_proc
select * from t1
drop proc if exists my_clr_proc

---------------------
/*Parametr Sniffing*/
---------------------
--выполняется обращение к статистике, идет расчет кол-ва строк, строится план (рачетное кол-во строк 1 -> исп NCI и Key Lookup)
CREATE PROCEDURE List_orders_1 AS
   SELECT * FROM [Books] WHERE [ISBN] > '600-0100002500'
go

--при вызове ХП и идет анализ параметра, с кот. была вызвана ХП (это и есть Parametr Sniffing: сама ХП с параметром и идет "прослушивание параметров" при вызове)
--выполняется обращение к статистике, идет расчет кол-ва строк, строится план (рачетное кол-во строк 1 -> исп NCI и Key Lookup)
CREATE PROCEDURE List_orders_2 @fromdate varchar(50) AS
   SELECT * FROM [Books] WHERE [ISBN]  > @fromdate
go

--входное значение копируется в локальную переменную, но SQL Server не имеет об этом никакого понятия, т.е. не знaет значение переменной
--он применяет стандартное предположение, которое для оператора неравенства, такого как «>» — заключается в 30%-ном коэффициенте эффективности поиска. 30% от кол-ва строк в таблице
CREATE PROCEDURE List_orders_3 @fromdate varchar(50) AS
   DECLARE @fromdate_copy varchar(50)
   SELECT @fromdate_copy = @fromdate
   SELECT * FROM [Books] WHERE [ISBN]  > @fromdate_copy
go

EXEC List_orders_1
EXEC List_orders_2 '600-0100002500'
EXEC List_orders_3 '600-0100002500'






