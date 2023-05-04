USE autopaymentsPSI
GO


DROP TABLE #TAB;
GO
---var 1---
CREATE TABLE #TAB (ID INT, geom1 GEOMETRY, geom2 as geom1.STAsText());
GO

INSERT INTO #TAB(ID,geom1)
VALUES (1,geometry::STGeomFromText('LINESTRING (100 100, 20 180, 180 180)',0));
GO

INSERT INTO #TAB(ID,geom1)
VALUES (1,geometry::STGeomFromText('POLYGON ((0 0, 150 0, 150 150, 0 150, 0 0))',0));
GO

SELECT * FROM #TAB;

---var 2---
CREATE TABLE #TAB (ID INT, geom GEOMETRY);
GO

INSERT INTO #TAB(ID,geom)
VALUES (1,'LINESTRING (100 100, 20 180, 180 180)');
GO

INSERT INTO #TAB(ID,geom)
VALUES (1,'POLYGON ((0 0, 150 0, 150 150, 0 150, 0 0))');
GO

SELECT * FROM #TAB;

---буквы---
DROP TABLE #TAB;
GO
CREATE TABLE #TAB (ID INT, geom GEOMETRY);
GO

INSERT INTO #TAB(ID,geom)
VALUES (1,'LINESTRING (0 0, 2 4, 4 0, 3 2, 1 2)')
, (2,'LINESTRING (6 0, 6 4, 10 4, 10 0)')
, (3,'LINESTRING (12 1, 12 3, 13 4, 15 4, 16 3, 16 1, 15 0, 13 0, 12 1)')
, (4,'LINESTRING (18 0, 22 4, 20 2, 20 0, 20 4, 20 2, 22 0, 18 4)')
GO

SELECT * FROM #TAB;


---график---
DROP TABLE #NUM;
DROP TABLE #TAB;
GO

CREATE TABLE #NUM (ID INT IDENTITY(1,1), ALL_C INT, OK_C INT, ERR_C INT);
CREATE TABLE #TAB (id varchar(5), geom GEOMETRY);
GO

INSERT INTO #TAB(id)
VALUES ('all')
,('ok')
,('err')


INSERT INTO #NUM
VALUES (5,3,2)
,(6,5,1)
,(7,3,4)
,(6,4,2)
,(6,3,3)
,(7,4,3)
,(5,3,2)
,(7,4,3)

WITH TAB AS (
select 
	ID
	, ALL_C 
	, ', ' + CAST(ID AS varchar(5))+ ' ' + CAST(ALL_C AS varchar(5)) 'ALL_CNT'
	, OK_C 
	, ', ' + CAST(ID AS varchar(5))+ ' ' + CAST(OK_C AS varchar(5)) 'OK_CNT' 
	, ERR_C 
	, ', ' + CAST(ID AS varchar(5))+ ' ' + CAST(ERR_C AS varchar(5)) 'ERR_CNT'
from #NUM 
),
TAB_STR as (
	select distinct stuff((select cast(ALL_CNT as varchar(10))
		from TAB 
		for xml path('')),1,1,'') 'ALL_S'
		, stuff((select cast(OK_CNT as varchar(10))
		from TAB 
		for xml path('')),1,1,'') 'OK_S'
		,stuff((select cast(ERR_CNT as varchar(10))
		from TAB 
		for xml path('')),1,1,'') 'ERR_S'
	from TAB
),
TAB_UN as(
	select 'all' 'id_s', 'LINESTRING (' + ALL_S + ')' 'string' from TAB_STR
	union
	select 'ok','LINESTRING (' + OK_S + ')' from TAB_STR
	union
	select 'err','LINESTRING (' + ERR_S + ')' from TAB_STR
)
--select * from TAB_UN
update #TAB 
set geom = (select string from TAB_UN t where id = t.id_s )

select * from  #TAB 
