------------------------------------------------
--работа с каталогами и файлами
------------------------------------------------
exec xp_cmdshell 'dir p:\system_db'
exec xp_cmdshell 'dir K:\_data\Cards'

exec xp_cmdshell 'dir K:\_new'
exec xp_cmdshell 'dir K:\_UPLOAD\'

exec xp_cmdshell 'tree P:\ /f'

exec xp_cmdshell 'dir K:\_backup\new\*.bak'
exec xp_cmdshell 'dir r:\_backup\new'
exec xp_cmdshell 'tree k:\_UPLOAD /f' --просмотр дерева каталогов, /f - вместе с файлами

exec xp_cmdshell 'md I:\system_db' --создание каталога

exec xp_cmdshell 'xcopy k:\_data v:\_data /T /E' --копировать структуру каталогов без файлов

exec xp_cmdshell 'copy N:\_backup\new\*.bak R:\_backup\new' --копирование файлов (с расширением .bak) в другую директорию

exec xp_cmdshell 'move i:\smp\iyttyt190116.bak J:\Backup' --перемещаем файл откуда/куда

exec xp_cmdshell 'del K:\_new\new_20190120.bak' --удаление файла
exec xp_cmdshell 'del K:\_new /q' --удаление каталога без подтверждения

------------------------------------------------
--системная инфо
------------------------------------------------
exec xp_cmdshell 'wmic memorychip get Manufacturer,Capacity,PartNumber,Speed' --инфо о ОЗУ на хосте

exec xp_cmdshell 'wmic logicaldisk get name, size, freespace' --инфо о дисках на хосте

exec xp_cmdshell 'whoami' --под каким пользователем запускается процесс

exec xp_cmdshell 'net share' --список расшаренных ресурсов, не работает
--------------------------------------------------------------------
--exec xp_cmdshell 'copy N:\_backup\new\*.bak R:\_backup\new'

exec xp_cmdshell 'tree k:\backup.sql'
exec xp_cmdshell 'tree N:\ /f'
exec xp_cmdshell 'tree x:\_UPLOAD /f'

