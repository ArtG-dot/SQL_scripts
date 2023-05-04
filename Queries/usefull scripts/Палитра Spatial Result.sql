USE autopaymentsPSI
GO

--CREATE TABLE #TAB (ID INT, POLIGON GEOMETRY);
--SELECT * FROM #TAB;
TRUNCATE TABLE #TAB;
DECLARE @X INT = 0, @Y INT = 0;


--------------КВАДРАТЫ-----------------
WHILE (@Y < 10)
BEGIN
	WHILE (@X < 10)
	BEGIN
		INSERT INTO #TAB VALUES (@Y*10+@X, 'POLYGON(('+
		CAST(@X AS VARCHAR(2))+' '+CAST(@Y AS VARCHAR(2))+', '+
		CAST(@X+1 AS VARCHAR(2))+' '+CAST(@Y AS VARCHAR(2))+', '+
		CAST(@X+1 AS VARCHAR(2))+' '+CAST(@Y+1 AS VARCHAR(2))+', '+
		CAST(@X AS VARCHAR(2))+' '+CAST(@Y+1 AS VARCHAR(2))+', '+
		CAST(@X AS VARCHAR(2))+' '+CAST(@Y AS VARCHAR(2))+'))');
		SET @X = @X + 1;
	END
	SET @X = 0;
	SET @Y = @Y +1;
END;


--------------------ЛИНИИ------------------
--WHILE (@Y < 10)
--BEGIN
--	WHILE (@X < 10)
--	BEGIN
--		INSERT INTO #TAB VALUES (@Y*10+@X, 'LINESTRING('+
--		CAST(@X AS VARCHAR(2))+' '+CAST(@Y AS VARCHAR(2))+', '+
--		CAST(@X+1 AS VARCHAR(2))+' '+CAST(@Y+1 AS VARCHAR(2))+')');
--		SET @X = @X + 1;
--	END
--	SET @X = 0;
--	SET @Y = @Y +1;
--END

SELECT * FROM #TAB ORDER BY ID;


