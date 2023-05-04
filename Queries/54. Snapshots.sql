/*snaphot - снимок БД; туда записываются изменения в данных с момента создания снимка
можно создать снимок перед изменением данных и затем восстановить данные на момент создания снимка.
Чем дольше сохраняется снимок тем больше он в объеме.

Снимок - это read-only БД без журнала

нельзя удалить исходную БД, если у нее есть снимок
*/



create database <db_snapshot_nm> on
(
	name = 'DB_snapshot'
	, file name = 'c:\DB_snapshot.ss'
) as snapshot of <db_nm>

create database <db_snapshot_nm> on
(
	name = 'resource_DB'
	, file name = 'c:\DB_snapshot.snap'
) as snapshot of <resource_DB_name>



/*восстановление БД на момент создания снимка*/
restore database <db_nm> from database_snapshot = 'db_snapshot_nm'