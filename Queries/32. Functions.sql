/*
UDF (user-defined function):
	Table-valued functions
	Scalar-valued functions
	Aggregate functions


*/

drop function if exists fun_test; --с  2016
go 


/*Scalar-valued functions*/
create or alter function dbo.fun_test(@a int, @b int)
returns int --data type which function returns
as
begin
	return @a + @b;
end;

select dbo.fun_test(2,3) fun_result; --всегда указывать схему 



/*Table-valued functions*/
create or alter function dbo.fun_test(@a int, @b int)
returns @tab table (
				par1 int null,
				par2 int null,
				f_sum int null)
as
begin
	insert into @tab values (@a, @b, @a+@b);
	return; 
end;

select * from dbo.fun_test(2,3); --всегда указывать схему 





-----------------------
/*CLR Functions*/
-----------------------
--ВАЖНО!!! имя класса и метода регистрочувствительны
create function	my_clr_fun (@ActB int)
returns nvarchar(30)
as external name CLR_Test.MyCheck.isActive --[Имя сборки].[Имя класса].[Имя метода]

Sp_configure 'clr enabled', 1
go

reconfigure
go

select dbo.my_clr_fun(0), dbo.my_clr_fun(1) --имя функции указывать со схемой