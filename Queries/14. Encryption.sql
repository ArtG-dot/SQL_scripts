/*
SQL Server encrypts data with a hierarchical encryption and key management infrastructure. 
Each layer encrypts the layer below it by using a combination of certificates, asymmetric keys, and symmetric keys. 
Asymmetric keys and symmetric keys can be stored outside of SQL Server in an Extensible Key Management (EKM) module.


Encryption Hierarchy:
Windows Level
		DPAPI (Data Protection API)						(Windows Operating System Level )
SQL Server Level
		Service Master Key (SMK)						(Created by SQL Server setup, symmetric key, encrypted by DPAPI)
Database Level
		Database Master Key (DMK)						(можно создать для каждой БД, только 1 в рамках БД, symmetric key, encrypted by SMK)
				1. Certificates							
						1.1. Symmetric Keys
								1.1.1. Symmetric Keys
								1.1.2. Data
						1.2. Data
				2. Asymmetric Keys
						2.1. Symmetric Keys
						2.2. Data



For best performance, encrypt data using symmetric keys instead of certificates or asymmetric keys.
Transparent Data Encryption (TDE) must use a symmetric key called the database encryption key which is protected by either a certificate protected by the database master key of the master database, or by an asymmetric key stored in an EKM.
The Service Master Key and all Database Master Keys are symmetric keys.



SQL Server provides the following mechanisms for encryption:
	Transact-SQL functions (ENCRYPTBYPASSPHRASE(), DECRYPTBYPASSPHRASE())
	Asymmetric keys (ключевая пара: public key и private key)
	Symmetric keys
	Certificates 
	Transparent Data Encryption


Certificate 
	(public key certificate)  по сути это контейнер для публичной части ключевой пары (public key) при асимметричном шифровании, 
	сертификат идентифицирует носителя private key, содержит информацию об эмитенте + его цифровую подпись (эмиент и владелец private key это разные объекты????))
	Сертификат служит для удобства: вместо хранения паролей для каждого субъекта хост устанавливает доверие к издателю сертификата, этот издатель может подписать неограниченное кол-во сертификатов
	The self-signed certificates created by SQL Server follow the X.509 standard and support the X.509 v1 fields.

An asymmetric key 
	is made up of a private key and the corresponding public key. Each key can decrypt data encrypted by the other. 
	Asymmetric encryption and decryption are relatively resource-intensive, but they provide a higher level of security than symmetric encryption. 
	An asymmetric key can be used to encrypt a symmetric key for storage in a database.

A symmetric key 
	is one key that is used for both encryption and decryption. Encryption and decryption by using a symmetric key is fast, 
	and suitable for routine use with sensitive data in the database.


Transparent Data Encryption (TDE) 
	is a special case of encryption using a symmetric key. TDE encrypts an entire database using that symmetric key called the database encryption key (DEK). 
	The database encryption key is protected by other keys or certificates which are protected either by the database master key or by an asymmetric key stored in an EKM module.

*/
--------------------------------------------------------------------------------------------
--------------------------------------------Info--------------------------------------------
--------------------------------------------------------------------------------------------
use master
select * from sys.symmetric_keys
select * from sys.asymmetric_keys
select * from sys.certificates
select * from sys.dm_database_encryption_keys 

select * from sys.column_master_keys 
select * from sys.key_encryptions
select * from sys.column_encryption_keys
select * from sys.column_encryption_key_values



--просмотр Service Master Key (SMK)	в БД master
use master
select * from sys.symmetric_keys where name like '%ServiceMasterKey%'
--where symmetric_key_id = 102

--просмотр Database Master Key (DMK) 
use <db_nm>
select * from sys.symmetric_keys where name like '%DatabaseMasterKey%'
--where symmetric_key_id = 101
			
			--просмотр всех способов шифрования DMK: ENCRYPTION BY MASTER KEY (с помощью SMK) или ENCRYPTION BY PASSWORD (с помощью пароля)
			--для DMK м.б. несколько паролей (ALTER MASTER KEY ADD ENCRYPTION BY PASSWORD) и одно шифрования с помощью SMK
			--если есть DMK тут всегда есть минимум 1 строка
			select * from sys.key_encryptions where key_id = (select symmetric_key_id  from sys.symmetric_keys where name like '%DatabaseMasterKey%')

--------------------------------------------------------------------------------------------
------------------------------------------Maintaince----------------------------------------
--------------------------------------------------------------------------------------------
--создание Database Master Key (DMK), ключ открывается автоматически и содержит 2 исходных метода шифрования (с помощью пароля и с помощью SMK)
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'super_secret_psw!!!';  

			--закрываем DMK
			CLOSE MASTER KEY;
			--открываем DMK, указывая один из паролей, которые шуфруют DMK
			OPEN MASTER KEY DECRYPTION BY PASSWORD = 'super_secret_psw!!!';
			--пересоздаем DMK, ВСЕ пароли, шифрующие DMK, удаляются и остается только 1 пароль, который мы указываем в выражении; если есть ENCRYPTION BY MASTER KEY, то оно сохраняется, если нет, то не появляется
			ALTER MASTER KEY REGENERATE WITH ENCRYPTION BY PASSWORD = 'psw_for_change';
			--удаляем шифрование DMK с помощью SMK (минус строка sys.key_encryptions)
			ALTER MASTER KEY DROP ENCRYPTION BY SERVICE MASTER KEY;
			--создаем шифрование DMK с помощью SMK (плюс строка sys.key_encryptions)
			ALTER MASTER KEY ADD ENCRYPTION BY SERVICE MASTER KEY;
			--добавляем еще один пароль, шифрующий DMK
			ALTER MASTER KEY ADD ENCRYPTION BY PASSWORD = 'new_super_secret_psw12332';
			--удаляем один из паролей, шифрующий DMK, должен оставаться минимум 1 пароль
			ALTER MASTER KEY DROP ENCRYPTION BY PASSWORD = 'super_secret_psw!!!'
			--удаляем DMK 
			DROP MASTER KEY;
			--бэкап DMK
			BACKUP MASTER KEY TO FILE = 'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup\Key_Cert\db_master_DMK.key' 
				ENCRYPTION BY PASSWORD = 'some_psw_for_backup';
			--восстановление DMK из бэкапа
			RESTORE MASTER KEY   
				FROM FILE = 'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup\Key_Cert\db_master_DMK.key'   
				DECRYPTION BY PASSWORD = 'some_psw_for_backup'   --пароль, который указали при бэкапе
				ENCRYPTION BY PASSWORD = 'new_psw_from_bkp';		--задаем пароль, шифрующий DMK






-----------------------------------
/*настройка TDE шифрования для БД*/
-----------------------------------
/*TDE (trasparent data encryption) - performs real-time I/O encryption and decryption of the data and log files 
The encryption uses a database encryption key (DEK), which is stored in the database boot record for availability during recovery. 
The DEK is a symmetric key secured by using a certificate stored in the master database of the server or an asymmetric key protected by an EKM module.

TDE шифрование обеспечивает защиту данных от доступа при отсутствии DEK

SQL Server Instance Level
	1. Create Service Master Key: Created at time SQL Server setup.
master Database Level
	2. Create Database master Key (DMK): CREATE MASTER KEY...
	3. Create Certificate in master DB: CREATE CERTIFICATE...
User Database level
	4. Create Database Encryption Key (DEK) by master Certificate: CREATE DATABASE ENCRYPTION KEY...
	5. Set trasparent data encryption on DB: ALTER DATABASE...SET ENCRYPTION ON
*/
--Create Database master Key
USE master;  
GO  
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'super_secret_psw';  
go

-- Create Certificate
CREATE CERTIFICATE MyServerCert WITH SUBJECT = 'My DEK Certificate';  
go  
--backup certificate to file
BACKUP CERTIFICATE	MyServerCert TO FILE = 'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup\Certificates\MySecretDB.cert'
WITH PRIVATE KEY (FILE = 'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup\Certificates\MySecretDB.key',
ENCRYPTION BY PASSWORD = '123456');

			--drop certificate 
			drop certificate MyServerCert

			--restore certificate to file
			CREATE CERTIFICATE	MyServerCert_bakup FROM FILE = 'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup\Certificates\MySecretDB.cert'
			WITH PRIVATE KEY (FILE = 'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup\Certificates\MySecretDB.key',
			DECRYPTION BY PASSWORD = '123456');

--Create Database Encryption Key (DEK)
USE TEST;  
GO  
CREATE DATABASE ENCRYPTION KEY  
	WITH ALGORITHM = AES_128  
	ENCRYPTION BY SERVER CERTIFICATE MyServerCert;  
GO
			--drop DEK
			ALTER DATABASE TEST SET ENCRYPTION OFF; 
			DROP DATABASE ENCRYPTION KEY 

--Set trasparent data encryption on DB  
ALTER DATABASE TEST SET ENCRYPTION ON;  

--pause the TDE encryption 
ALTER DATABASE <db_name> SET ENCRYPTION SUSPEND;
--resume the TDE encryption
ALTER DATABASE <db_name> SET ENCRYPTION RESUME;



-----------------------------
/*backup/restore DB with encryption*/
-----------------------------
--создание сертификата, затем бэкап БД
BACKUP DATABASE TEST TO DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup\TEST_encrypted.bak'
WITH ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = MyServerCert)
--восстановление обычным способом, сертификат указывать не надо, но нужно чтобы он был в БД master
RESTORE DATABASE TEST FROM DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup\TEST_encrypted.bak'



-------------------------------------
/*Implement Column Level Encryption*/
-------------------------------------

--Encrypt a Column of Data
--вариант 1. через SSMS: ПК на таблице -> Encrypt columns

--вариант 2. через T-SQL*/
--create Database Master Key (DMK) for database
use <db_nm>
if not exists (select * from sys.symmetric_keys where symmetric_key_id = 101)
	create master key encryption by password = 'super_secret_psw' 

--create a cert for use as the data encryption key (DEK)
create certificate PswCert
	with subject = 'user_data',
	EXPIRY_DATE = '12/05/2020'

--create a symmetryc key and encrypt it through the certificate
CREATE SYMMETRIC KEY User_sym_key  
    WITH ALGORITHM = AES_256  
    ENCRYPTION BY CERTIFICATE PswCert;  

--Open the symmetric key with which to encrypt the data.  
OPEN SYMMETRIC KEY User_sym_key  
   DECRYPTION BY CERTIFICATE PswCert;  

-- Create a table in which to store the encrypted column  
create table #tmp (id int identity, val varchar(20), val_e varbinary(100))
insert into #tmp(val) values 
('Password'),
('email'),
('some_data')

--encryping column
update #tmp
set val_e = EncryptByKey(Key_GUID('User_sym_key'),val) --в параметре указываем имя ключа для шифрования и колонку для шифрования
--EncryptByKey(Key_GUID('CreditCards_Key11'), CardNumber, 1, HashBytes('SHA1', CONVERT( varbinary, CreditCardID)));     

CLOSE SYMMETRIC KEY User_sym_key;

select * from #tmp
--drop table #tmp



--Decrypt a Column of Data
-- Open the symmetric key with which to decrypt the data.  
OPEN SYMMETRIC KEY User_sym_key  
   DECRYPTION BY CERTIFICATE PswCert;  
SELECT *
, cast( DecryptByKey(val_e) as varchar(20)) val_decrypt
--cast( DecryptByKey(CardNumber_Encrypted, 1 ,HashBytes('SHA1', CONVERT(varbinary, CreditCardID))) as varchar(20))  
FROM #tmp
 


 ----------------------------------------------------------
 /*цифровая подпись для программных модулей в SQL Server */
 ----------------------------------------------------------
 /*A digital signature is a data digest encrypted with the private key of the signer. 
 The private key ensures that the digital signature is unique to its bearer or owner. 
 You can sign stored procedures, functions (except for inline table-valued functions), triggers, and assemblies.*/

 --подписание хранимой процедуры
/*You can sign a stored procedure with a certificate or an asymmetric key. 
This is designed for scenarios when permissions cannot be inherited through ownership chaining or when the ownership chain is broken.
You can also create a login mapped to the same certificate, and then grant any necessary server-level permissions to that login, 
or add the login to one or more of the fixed server roles. 
This is designed to avoid enabling the TRUSTWORTHY database setting for scenarios in which higher level permissions are needed.
When the stored procedure is executed, SQL Server combines the permissions of the certificate user and/or login with those of the caller. 
Unlike the EXECUTE AS clause, it does not change the execution context of the procedure. Built-in functions that return login and user names 
return the name of the caller, not the certificate user name.
*/

--создадим сертификат, защищенный паролем
CREATE CERTIFICATE my_cert_psw
   ENCRYPTION BY PASSWORD = 'qwerty'  
      WITH SUBJECT = 'Credit Rating Records Access',   
      EXPIRY_DATE = '12/05/2020';

--подпишем ХП
ADD SIGNATURE TO my_SP   
   BY CERTIFICATE my_cert_psw  
    WITH PASSWORD = 'qwerty';  
GO 

--создадим пользователя на основе сертификата
CREATE USER usr_cert  
   FROM CERTIFICATE my_cert_psw;  


--раздадим права пользователю на исполнение ХП
   GRANT SELECT   
   ON Purchasing.Vendor   
   TO usr_cert;  
GO  
  
GRANT EXECUTE   
   ON my_SP   
   TO usr_cert;  
GO  
