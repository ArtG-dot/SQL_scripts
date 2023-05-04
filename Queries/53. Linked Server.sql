--------------------------------------------------------------------------------------------
---------------------------------------------Info-------------------------------------------
--------------------------------------------------------------------------------------------
/*
Distributed Transaction Coordinator

SQL Server Service Broker manages communication between servers

*/


/*
пусть есть 2 сервера: DstSrv(сервер назначения) и SrcSrv(сервер источник)
1. технология Pull
на сервере DstSrv выполняем запрос:
insert into <table>
	select * from SrcSrv.db.dbo.<table>

мы "тянем" данные с удаленного сервера источника на текущий сервер назначения.
в этом случае вставка происходит пакетно, т.е. с высокой скоростью

2. технология Push
на сервере SrcSrv выполняем запрос:
insert into DstSrv.db.dbo.<table>
	select * from <table>

мы "отправляем" данные с текущего сервера источника на удаленный сервер назначения.
в этом случае вставка происходит по одной записи, т.е. с низкой скоростью
*/


USE [master]
GO

/*список всех linked servers*/
exec sp_linkedservers

select * from sys.servers
select * from sys.sysservers

/*список всех linked servers + список пользователей, под которыми идет подключение*/
select * 
from sys.servers s
left join sys.linked_logins l
	on s.server_id = l.server_id
left join sys.server_principals p
	on l.local_principal_id = p.principal_id
order by s.provider, s.name


--------------------------------------------------------------------------------------------
------------------------------------------Maintaince----------------------------------------
--------------------------------------------------------------------------------------------
/*создание linked server*/
EXEC master.dbo.sp_addlinkedserver 
	@server = N'server' --наименование linked server
	, @srvproduct = N'product_name' --название продукта для источника данных OLE DB. Если SQL Server, то @provider, @datasrc, @location, @provstr и @catalog не должны задаваться.
	, @provider = N'provider_name' --уникальный программный идентификатор (PROGID) поставщика OLE DB, соответствующий источнику данных
	, @datasrc = N'data_source' --имя источника данных, как оно интерпретируется поставщиком OLE DB
	, @location = N'location'--местоположение БД, понятное поставщику OLE DB
	, @provstr = N'provider_string'--тсрока подключения для конкретного поставщика БД
	, @catalog = N'catalog' --каталог, кот. должен использрваться при подключении к поставщику OLE DB (имя БД?)

/*создание linked server с типом MS SQL Server с именем хоста CAB-SOP-SQL0009 и экземпляром по умолчанию MSSQLSERVER, 
для именнованного экземпляра <host_name>\<instance_name>. Достаточно имени сервера и product_name = SQL Server */
EXEC master.dbo.sp_addlinkedserver 
	@server = N'SQL0009'
	, @srvproduct = N'SQL Server';

/*для SQL Server можно исп provider_name = SQLNCLI*/
EXEC master.dbo.sp_addlinkedserver 
	@server = N'A13' 
	,@srvproduct=N'A13-T7500-W7'
	,@provider=N'SQLNCLI'
	,@datasrc=N'A13-T7500-W7'

EXEC master.dbo.sp_addlinkedserver 
	@server = N'SQL0009-TEST'
	, @srvproduct=N''
	, @provider=N'SQLNCLI'
	, @datasrc=N'SQL0009'
	, @catalog=N'new_VVB'

/*создание linked server с типом Oracle*/
EXEC master.dbo.sp_addlinkedserver 
	@server = N'PROM' --наименование linked server
	, @srvproduct = N'Oracle' --название продукта для источника данных OLE DB
	, @provider = N'OraOLEDB.Oracle' --уникальный программный идентификатор (PROGID) поставщика OLE DB
	, @datasrc = N'dis:1521/dis' --имя источника данных
	, @catalog = N'PORTS' --каталог, имя БД?

/*создание linked server с типом MS Excel*/
EXEC master.dbo.sp_addlinkedserver
	@server = N'S1'
	, @srvproduct = N'ACE 12.0'
	, @provider = N'Microsoft.ACE.OLEDB.12.0'
	, @datasrc = N'I:\_data\ddd\ddd.xlsx'
	, @provstr = N'Excel 12.0;HDR = Yes;IMEX = 1'

/*
настройка подключения к linked server, вкладка Security 
*/
/*если на стороне linked server с типом SQL Server смешанная аутентификация, то нужно исп. у/з SQL Server
если исп у/з Windows мб проблемы подключением: Login failed for user 'domain/user'. Reason: Attempting to use an NT account name with SQL Server Authentication*/
EXEC master.dbo.sp_addlinkedsrvlogin 
@rmtsrvname = N'SQL0009'
,@useself = N'False'
,@locallogin = NULL
,@rmtuser = N'currency_upload_login'
,@rmtpassword = '########'
GO

/*настройка linked server, вкладка Server Option*/
EXEC master.dbo.sp_serveroption 
@server = N'SQL0009'
, @optname = N'remote proc transaction promotion'
, @optvalue = N'true'
GO

/*проверка доступности linked server*/
declare @lnksrv_nm nvarchar(50);
declare @err int;
declare @err_str nvarchar(200)
set @lnksrv_nm = 'AR'
set @err_str = 'Test connection failed. Please check linked server ' + @lnksrv_nm + ' properties'

begin try
	exec @err = sp_testlinkedserver @lnksrv_nm
end try
begin catch
	set @err = @@ERROR
end catch

if @err <> 0 
	THROW 500001, @err_str, 1;



	exec sp_testlinkedserver N'ODS_M'




	select  * from openrowset('Microsoft.ACE.OLEDB.12.0', 'Excel 12.0;Database=I:\_data\KP\1.xlsx;HDR=NO;IMEX=1', 'Select * from [FCRED$C9:AQ]')
	exec (N'drop table "_Risk"."TMP_PORT"') at linked_server

--берем лист FCRED и тянем все с ячеек C9:AQ