----------------------------------------
/*представление данных в бинарном виде*/
----------------------------------------

--(DEC) to (HEX)
select 
CONVERT(BINARY(1), 255) [1_byte] --в параметре BINARY - сколько байт отображать
, CONVERT(BINARY(1), 256) [1_byte] --ошибки не будет, просто данные отразятся не полностью
, CONVERT(BINARY(2), 256) [2_bytes]
, cast(255 as varbinary)

--(HEX) to (DEC)
SELECT CAST(0x00FF AS int)

--(DEC) to (BIN)
declare @intvalue int = 255; --число
declare @bytes int = 2; --кол-во байт для представления
declare @vsresult varchar(200) = '';
declare @i int = 1;

while @i < @bytes * 8 + @bytes * 2
  begin
	if (@i % 5 = 0) select @vsresult = ' ' + @vsresult, @i=@i+1
	else 
		begin
			select @vsresult = convert(char(1), @intvalue % 2)+@vsresult
			select @intvalue = convert(int, (@intvalue / 2)), @i=@i+1
		end
  end
select @vsresult

			--функция для удобства
			drop function if exists dbo.int_to_bin;

			create function dbo.int_to_bin ( @intvalue int, @bytes int)
			returns varchar(200)
			as
			begin
				declare @i int = 1;
				declare @vsresult varchar(200) = '';
				while @i < @bytes * 8 + @bytes * 2
				  begin
					if (@i % 5 = 0) select @vsresult = ' ' + @vsresult, @i=@i+1
					else 
						begin
							select @vsresult = convert(char(1), @intvalue % 2)+@vsresult
							select @intvalue = convert(int, (@intvalue / 2)), @i=@i+1
						end
				  end
				return @vsresult
			end

			SELECT dbo.int_to_bin (255,1) [1_byte]
			, dbo.int_to_bin (256,1) [1_byte]
			, dbo.int_to_bin (256,2) [2_byte]



--(BIN) to (DEC)

CREATE FUNCTION [dbo].[BinaryToDecimal]
(
	@Input varchar(255)
)
RETURNS bigint
AS
BEGIN

	DECLARE @Cnt tinyint = 1
	DECLARE @Len tinyint = LEN(@Input)
	DECLARE @Output bigint = CAST(SUBSTRING(@Input, @Len, 1) AS bigint)

	WHILE(@Cnt < @Len) BEGIN
		SET @Output = @Output + POWER(CAST(SUBSTRING(@Input, @Len - @Cnt, 1) * 2 AS bigint), @Cnt)

		SET @Cnt = @Cnt + 1
	END

	RETURN @Output	

END
SELECT dbo.BinaryToDecimal('11101011001011010101111010000')




/*
Битовые операции:
ИЛИ								И
0 | 0	->	0					0 & 0	->	0
0 | 1	->	1					0 & 1	->	0
1 | 0	->	1					1 & 0	->	0
1 | 1	->	1					1 & 1	->	1

*/


--------------------
/*битовые операции*/
--------------------
--ИЛИ
SELECT (4 | 6)	-- 6, т.е. 0000 0100 | 0000 0110 = 0000 0110
SELECT (5 | 12) --13, т.е. 0000 0101 | 0000 1100 = 0000 1101
SELECT (5 | 10) --15, т.е. 0000 0101 | 0000 1010 = 0000 1111
SELECT (1 | 2 | 4 | 8 | 32) AS [результат операции ИЛИ, битовое значение, содержащее числа 1, 2, 4, 8 и 32]
SELECT (1 | 2 | 4 | 8 | 16) AS [результат операции ИЛИ, битовое значение, содержащее числа 1, 2, 4, 8 и 16]

--И
SELECT (4 & 6)	-- 4, т.е. 0000 0100 | 0000 0110 = 0000 0100
SELECT (5 & 12) -- 4, т.е. 0000 0101 | 0000 1100 = 0000 0100
SELECT (5 & 10) -- 0, т.е. 0000 0101 | 0000 1010 = 0000 0000

--ИЛИ + И
SELECT ((1 | 2 | 4 | 8 | 32) & 2) AS [результат операции И, число 2 найдено]
SELECT ((1 | 4 | 8 | 32)) & 2 AS [результат операции И, число 2 НЕ найдено]

--пример
DECLARE @i int;
SET @i = 1 | 2 | 4 | 8 | 32;
SELECT (@i & 32) AS [результат операции И, число 32 найдено]
SELECT (@i & 64) AS [результат операции И, число 64 НЕ найдено]

IF (@i & 8) = 8 BEGIN
  SELECT 'Есть число 8!'
END;

IF (@i & 128) = 0 BEGIN
  SELECT 'Число 128 отсутствует...'
END;








-------------------------------------------------------------------------------------------------------------------
declare @mybinary varbinary(12)
set @mybinary = 0x24
select @mybinary  --результат 0x24
set @mybinary = 0x024
select @mybinary  --результат 0x0024
/*
	
	внешнее представление строки битов - шестнадцатиричное
	причем если строка содержит не целое число байтов, она 
	будет добита нулями слева до целого при операции 
	присвоения (но сохраненное в БД значение само по себе не трансформируется :) ).
	Нам правда все равно, сравнение битов начинается справа
	один байт принимает значения от 0x00 до 0xFF (восемь бит)
	0x00 - 0000 0000 - 0
	0x01 - 0000 0001 - 1 
	0x02 - 0000 0010 - 2
	0x03 - 0000 0011 - 3
	0x04 - 0000 0100 - 4
	0x05 - 0000 0101 - 5
	0x06 - 0000 0110 - 6
	0x07 - 0000 0111 - 7
	0x08 - 0000 1000 - 8
	0x09 - 0000 1001 - 9
	0x0a - 0000 1010 - 10
	0x0b - 0000 1011 - 11
	0x0c - 0000 1100 - 12
	0x0d - 0000 1101 - 13
	0x0e - 0000 1110 - 14
	0x0f - 0000 1111 - 15
	...
*/
declare @template int
set @template = 4 -- 0000 1000 состояние 3-го бита

declare @result int
declare @myint  int 
set @myint = cast(@mybinary as int)
select  @myint -- результат 36 или двоичный .... .... 0010 0100  = 2^5 + 2^2
if ((@myint & @template) = @template) select 'this bit is 1'
else select 'this bit is 0'
----------------------------------------------------------------------------------------------------------------------------------



select 
CONVERT(int, )
, CONVERT(int, 0xFF)


select CONVERT(BINARY(30), CONVERT(BIGINT, 255))

select 
cast(0xCD as int)
, dbo.int_to_bin (cast(0xCD as int),2)
, sys.fn_IsBitSetInBitmask(0xCD, 3)
, dbo.int_to_bin (sys.fn_IsBitSetInBitmask(0xCD, 3),2)

	



select sys.fn_IsBitSetInBitmask(convert(VARBINARY, 2),2)
select sys.fn_IsBitSetInBitmask(convert(VARBINARY, 0x2),2)

select sys.fn_MStestbit


 if   (sys.fn_IsBitSetInBitmask(convert(VARBINARY, 0xa),2)<> 0)
        if   (sys.fn_IsBitSetInBitmask(convert(VARBINARY, 0xa),4) <> 0)
           select 'sup son'




     select sys.fn_IsBitSetInBitmask(convert(VARBINARY, 0xa),4)	

	  COLUMNS_UPDATED() 