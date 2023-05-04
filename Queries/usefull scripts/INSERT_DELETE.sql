CREATE TABLE #Temp
	(ID int,
	Name nvarchar(20))
	




INSERT #Temp(Name)
SELECT DISTINCT Name
FROM Test_Table

--копировать только структуру таблицы без записей
SELECT ID, Name
INTO #Temp
FROM Test_Table
where 1=2




SELECT TOP (1000) [c1]
      ,[c2]
  FROM [TEST].[dbo].[t1]


  insert into t1
  output inserted.* --вывод вставленных строк
  values (11, 'w')
  
  delete t1
  output deleted.* --вывод удаленных строк
  where c1 = 10
