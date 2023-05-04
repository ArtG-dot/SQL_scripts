use Test
go

set concat_null_yields_null on
declare 
	@collist varchar(max),
	@srch_sql varchar(max),
	@schemaName varchar(128),
	@tableName varchar(128)

declare curs cursor local static forward_only for 
	select distinct c.TABLE_SCHEMA, c.TABLE_NAME
	from INFORMATION_SCHEMA.[COLUMNS] c
	where c.DATA_TYPE in('char', 'varchar', 'nvarchar', 'text')
	and c.CHARACTER_MAXIMUM_LENGTH >=4
	and objectproperty(object_id(c.TABLE_SCHEMA + '.'+ c.TABLE_NAME), 'IsUserTable ') = 1
	order by 1, 2
open curs
while 1=1
begin

	fetch next from curs into @schemaName, @tableName
	if @@FETCH_STATUS <> 0 break

-- ƒанную строку можно раскомментарить, если хочется видеть, в какой таблице идет поиск в данный момент	
--raiserror(';%s.%s', 10, 1, @schemaName, @tableName) with nowait

	select
		@collist = null
		
	select 
		@collist = isnull(@collist + '
	or ', '') +'upper(convert(varchar(8000), ' + c.COLUMN_NAME + ')) like ''%атинское%''' -- “ут указываем, что и как ищем 
	from INFORMATION_SCHEMA.[COLUMNS] c
	where c.TABLE_SCHEMA = @schemaName
	and c.TABLE_NAME = @tableName
	and c.DATA_TYPE in('char', 'varchar', 'nvarchar', 'text')
	and c.CHARACTER_MAXIMUM_LENGTH >=6
	set @srch_sql = 'if exists(select * from '+@schemaName+'.'+@tableName+' with(nolock) where '+@collist+')
	raiserror('''+@schemaName+'.'+@tableName+' - found!'', 10, 1) with nowait'
	
	exec(@srch_sql)
end