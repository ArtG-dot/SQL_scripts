-------------------------------------
/*настройка пользовательской сессии*/
-------------------------------------
--проверка параметра 'user options' в настройках сервера
select * from sys.configurations where name = 'user options'

--активные параметра SET для “≈ ”ў≈√ќ соединения
--вариант 1
dbcc useroptions
--вариант 2
select @@OPTIONS

			dbcc useroptions --13 rows
			select @@OPTIONS --5496
				set nocount on	 --вкл настройку
			dbcc useroptions --14 rows
			select @@OPTIONS --6008
				set nocount off  --выкл настройку
			dbcc useroptions --13 rows
			select @@OPTIONS --5496

/*текущие настройкт пользовательской сессии в десятичном формате
Ќапример: @@OPTIONS = 5496 (DEC) = 001010101111000 (BIN)
1 - параметр включен, 0 - выключен */
select @@OPTIONS

			--перевод из DEC в BIN
			declare @intvalue int = @@OPTIONS

			declare @vsresult varchar(15) = ''
			declare @i int = 15
			while @i > 0
			  begin
				set @vsresult=convert(char(1), @intvalue % 2) + @vsresult
				set @intvalue = convert(int, (@intvalue / 2)) 
				set @i = @i - 1
			  end
			select @vsresult

/* параметры справа налево
1		1		DISABLE_DEF_CNST_CHK		Controls interim or deferred constraint checking.
2		2		IMPLICIT_TRANSACTIONS		For dblib network library connections, controls whether a transaction is started implicitly when a statement is executed. The IMPLICIT_TRANSACTIONS setting has no effect on ODBC or OLEDB connections.
3		4		CURSOR_CLOSE_ON_COMMIT		Controls behavior of cursors after a commit operation has been performed.
4		8		ANSI_WARNINGS				Controls truncation and NULL in aggregate warnings.
5		16		ANSI_PADDING				Controls padding of fixed-length variables.
6		32		ANSI_NULLS					Controls NULL handling when using equality operators.
7		64		ARITHABORT					Terminates a query when an overflow or divide-by-zero error occurs during query execution.
8		128		ARITHIGNORE					Returns NULL when an overflow or divide-by-zero error occurs during a query.
9		256		QUOTED_IDENTIFIER			Differentiates between single and double quotation marks when evaluating an expression.
10		512		NOCOUNT						Turns off the message returned at the end of each statement that states how many rows were affected.
11		1024	ANSI_NULL_DFLT_ON			Alters the session's behavior to use ANSI compatibility for nullability. New columns defined without explicit nullability are defined to allow nulls.
12		2048	ANSI_NULL_DFLT_OFF			Alters the session's behavior not to use ANSI compatibility for nullability. New columns defined without explicit nullability do not allow nulls.
13		4096	CONCAT_NULL_YIELDS_NULL		Returns NULL when concatenating a NULL value with a string.
14		8192	NUMERIC_ROUNDABORT			Generates an error when a loss of precision occurs in an expression.
15		16384	XACT_ABORT					Rolls back a transaction if a Transact-SQL statement raises a run-time error.
*/

/*Ѕитовые операции:
»Ћ»								»
0 | 0	->	0					0 & 0	->	0
0 | 1	->	1					0 & 1	->	0
1 | 0	->	1					1 & 0	->	0
1 | 1	->	1					1 & 1	->	1
*/

--меняем определенную настройку для пользовательских сессий с учетом текущих настроек 
--SSMS -> RC on server -> Properties -> Connections -> Default connections options
declare @value int;
select	@value = cast(value as int) from sys.configurations where name = 'user options';

--берем настройки сервера по умолчанию для нового соединения и применяя битовую операцию с использованием поля value меняем настройку сессии*/
if (@value & 512 = 0) --например добавляем включение настройки ARITHABORT (64)
	set @value += 512;

exec sp_configure 'user options', 512
go
reconfigure
go



insert temp select 1;


set nocount 


DECLARE @NOCOUNT VARCHAR(3) = 'OFF';  
IF ( (512 & @@OPTIONS) = 512 ) SET @NOCOUNT = 'ON';  
SELECT @NOCOUNT AS NOCOUNT; 



/*включение сбора статистики*/
set statistics io, time on;

set statistics io on/off
/*
Number of seeks/scans started after reaching the leaf level in any direction to retrieve all the values to construct the final dataset for the output.
Ц Scan count is 0 if the index used is a unique index or clustered index on a primary key and you are seeking for only one value. For example WHERE Primary_Key_Column = @a
Ц Scan count is 1 when you are searching for one value using a non-unique clustered index which is defined on a non-primary key column. »ли идет index scan
Ц Scan count is N when N is the number of different seek/scan started towards the left or right side at the leaf level after locating a key value using the index key.

Ќапример:
1. “аблица в виде кучи
SELECT * FROM dbo.Person									Scan count 1
SELECT * FROM dbo.Person WHERE BusinessEntityID = 1			Scan count 1
SELECT * FROM dbo.Person WHERE BusinessEntityID IN (1,2,3)	Scan count 1

2. “аблица в виде CI
SELECT * FROM dbo.Person									Scan count 1
SELECT * FROM dbo.Person WHERE BusinessEntityID = 1			Scan count 0
SELECT * FROM dbo.Person WHERE BusinessEntityID IN (1,2,3)	Scan count 3



Ц Logical Reads: are the number of 8k Pages read from the Data Cache. These Pages are placed in Data Cache by Physical Reads or Read-Ahead Reads.
Ц Physical Reads: are the Number of 8k Pages read from the Disk if they are not in Data Cache. Once in Data Cache they (Pages) are read by Logical Reads and Physical Reads do not (or minimally) happen for same set of queries.
Ц Read-Ahead Reads: are the number of 8k Pages pre-read from the Disk and placed into the Data Cache. These are a kind of advance Physical Reads, as they bring the Pages in advance to the Data Cache where the need for Data/Index pages in anticipated by the query.
*/


set statistics time on/off;

