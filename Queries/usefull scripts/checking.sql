/*проверка linked server*/
DECLARE @lnksrv_nm NVARCHAR(50);
DECLARE @err INT;
DECLARE @err_str NVARCHAR(200);

SET @lnksrv_nm = 'PROM';
SET @err_str = 'Test connection failed. Please check linked server ' + @lnksrv_nm + ' properties';

BEGIN TRY
	EXEC @err = sp_testlinkedserver @lnksrv_nm
END TRY
BEGIN CATCH
	SET @err = @@ERROR
END CATCH;

IF @err <> 0 
	THROW 500001, @err_str, 1;


/*проверка существования файла*/
CREATE TABLE #filename (file_nm varchar(100));

INSERT INTO #filename
	EXEC xp_cmdshell 'dir I:\_upload\opt.csv';

DELETE FROM	#filename
	WHERE	ISNULL(file_nm, '') NOT LIKE '%opt.csv';

IF (SELECT COUNT(*) FROM #filename) <> 1
	THROW 500001, 'check file', 1;

DROP TABLE #filename; --не будет выполнено явно, если произойдет ошибка


/*проверка существования таблицы*/
/*вариант 1*/
IF (NOT EXISTS (SELECT * FROM sys.tables WHERE NAME = 'prefix'))
	CREATE TABLE [dbo].[prefix_ps_temp] ([ID_DEAL] [nvarchar](255) NULL);

/*вариант 2*/
IF OBJECT_ID(N'KP.dbo.prefix', N'U') IS NOT NULL
	DROP TABLE [dbo].[prefix_ps_temp] 

/*вариант 3 (с 2016)*/
DROP TABLE IF EXISTS [dbo].[prefix_ps_temp]; 




-----------------------------------------------------------------------------------------------------------------------------

/*parameter list*/
declare @s_dir_str	nvarchar(500);
declare @d_dir_str	nvarchar(500);
declare @cmd_ctr	nvarchar(500);
declare @year		char(4)
declare @mon		char(2);
declare @day		char(2);
declare @f_cnt		int;
declare @temp		table (i_str nvarchar(500));

/*parameter value*/
set @s_dir_str	= 'I:\_uploadc1';
set @d_dir_str	= 'I:\_upload\dst';
set @f_cnt		= 4
set @year		= cast(year(dateadd(month,-1,GETDATE())) as char(4))
set @mon		= right('0' + cast(month(dateadd(month,-1,GETDATE())) as varchar(2)),2);
set @day		= right('0' + cast(day(eomonth(dateadd(month,-1,GETDATE()))) as varchar(2)),2);

print 'INFO: Начало процедуры загрузки файлов на дату: ' + @year + '.' + @mon + '.' + @day

/*checking of source directory*/
------------------------добавить проверку по дате--------------------
set @cmd_ctr = 'dir ' + @S_dir_str + '\' + @mon + '.' + @day
insert into @temp exec xp_cmdshell @cmd_ctr
select * from @temp

if (select count(*) from @temp where i_str like '%File(s)%') = 0
	begin
		print 'ERROR: Исходная директория ' + @s_dir_str + ' не существует !'
		--goto error
	end
else
	print 'INFO: Исходная директория ' + @s_dir_str + ' существует';

if (select CAST(LEFT(i_str,CHARINDEX('File(s)',i_str)-2) as int) f_cnt from @temp where i_str like '%File(s)%') != @f_cnt
	begin
		select CAST(LEFT(i_str,CHARINDEX('File(s)',i_str)-2) as int) f_cnt from @temp where i_str like '%File(s)%'
		print 'ERROR: Исходная директория ' + @s_dir_str + ' содержит некорректное число файлов формата .TXT !'
		--goto error
	end
else
 select CAST(LEFT(i_str,CHARINDEX('File(s)',i_str)-2) as int) f_cnt from @temp where i_str like '%File(s)%'
	print 'INFO: Исходная директория ' + @s_dir_str + ' содержит корректное число файлов формата .TXT'

/*checking of distanation directory*/
set @cmd_ctr = 'dir ' + @d_dir_str
insert into @temp exec xp_cmdshell @cmd_ctr
if (select CAST(LEFT(i_str,CHARINDEX('File(s)',i_str)-2) as int) f_cnt from @temp where i_str like '%File(s)%') != 0
	begin
		print 'WARN: Временная директория ' + @d_dir_str + ' не пуста!'
		print 'INFO: Начато удаление файлов из временной директории.'
	--	@cmd_ctr = 'del ' + @d_dir_str + ' \q'
		print 'INFO: Временная директория очищена.'
	end
else 
	print 'INFO: Временная директория ' + @d_dir_str + ' пуста.'

print 'INFO: Начало загрузки файлов!'
