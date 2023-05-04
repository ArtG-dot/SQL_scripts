/*список расширенных процедур (extended procedure)
бд master -> Programmability -> Extended Store Procedure -> System Store Procedure
*/

/*возвращает сведения о хосте*/
exec master..xp_msver

/*не документированная !!!
получить текущую версию SQL Server*/
exec master..sp_MSgetversion 
select @@VERSION

/*не документированная !!!
получение WINS имя SQl Server*/
exec xp_getnetname
select @@SERVERNAME

/*не документированная !!!
размер свободного пространства дисков в МБ*/ 
exec xp_fixeddrives

/*не документированная !!!
получение списка всех подкаталогов: имя каталога, уровень вложенности*/
exec xp_dirtree 'k:\'

/*не документированная !!!
получение списка всех подкаталогов с уровнем воженности 1*/
exec xp_subdirs 'k:\'

/*не документированная !!!
определяет существует ли заданный файл на диске*/
exec xp_fileexist 'k:\text.txt', @is_exist OUTPUT --не проверял

/*выполнение переданной команды на ОС хоста
процесс Windows, сформированный командой xp_smdshell имеет те же права, что и SQL Server учетной записи службы*/
exec master..xp_cmdshell 'dir k:\'

/*впредоставляет список локальных групп MS Windows или список глобальных групп, определенных в указанном домене Windows*/
exec master..xp_enumgroups --не проверял
exec master..xp_enumgroups 'domain' --не проверял

/*возвращает сведения о пользователях и группах Windows*/
exec master..xp_logininfo --не проверял

/*(устар)
возвращает сведения о конфигурации безопасности входа в систему для экземпляра SQL Server*/
exec master..xp_loginconfig --не проверял
exec master..xp_loginconfig  'login mode' --не проверял

/*(устар)
предоставляет группе или пользователю Windows доступ к SQL Server*/
exec master..xp_grantlogin --не проверял

/*(устар)
отменяет у группы или пользователя Windows доступ к SQL Server */
exec master..xp_revokelogin --не проверял

/*не документированная !!!
возвращает содержимое errorlog файла*/
exec master..xp_readerrorlog

/*не документированная !!!
список всех файлов с логами SQL Server, журнал ошибок*/
exec master..xp_enumerrorlogs

/*заносит сообщение в файл журнала SQl Server и журнал событий Windows*/
exec master..xp_logevent --не проверял

/*формирует и сохраняет серию символов и значений в строковом выходном параметре*/
exec master..xp_sprintf --не проверял

/*сложное что-то*/
exec master..xp_sqlmaint --не проверял

/*сложное что-то*/
exec master..xp_sscanf --не проверял

/*не документированная !!!
список всех OLE DB провайдеров: Provider Name, Parse Name, Provider Description*/
exec master..xp_enum_oledb_providers --не проверял

/*не документированная !!!
список всех кодовых страниц, наборов символов и их описаний*/
exec master..xp_enumcodepages --не проверял

/*не документированная !!!
список всех DNS и их описание*/
exec master..xp_enumdns --не проверял


/*не документированная !!!
работа с системным реестром*/
exec master..xp_reg... --не проверял
