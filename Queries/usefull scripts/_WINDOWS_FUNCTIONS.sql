/*there are 2 basic behaviours:
range - by default - using Temp DB
frame - using Memory (from SQL Server 2012)*/



--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------

/*Ranking Functions: 
RANK, DENSE_RANK, ROW_NUMBER, NTILE */
SELECT p.FirstName, p.LastName  
    ,ROW_NUMBER()	OVER (ORDER BY a.PostalCode) AS "Row Number"  
    ,RANK()			OVER (ORDER BY a.PostalCode) AS Rank  
    ,DENSE_RANK()	OVER (ORDER BY a.PostalCode) AS "Dense Rank"  
    ,NTILE(4)		OVER (ORDER BY a.PostalCode) AS Quartile  
    ,s.SalesYTD  
    ,a.PostalCode  
FROM Sales.SalesPerson AS s  

--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------

/*Aggregate Functions: COUNT, COUNT_BIG, MIN, MAX, SUM, AVG, 
VAR - statistical variance
VARP - statistical variance for the population
STDEV - statistical standard deviation
STDEVP - statistical standard deviation for the population
CHECKSUM_AGG - checksum of the values in a group, ignores null values
STRING_AGG - Concatenates the values of string expressions and places separator values between them. The separator is not added at the end of string.
APPROX_COUNT_DISTINCT - approximate number of unique non-null values in a group
GROUPING
GROUPING_ID */
select p.BLOCKED_HOURS, p.MIN_INTERVAL, SUM(p.MIN_INTERVAL) over() from ap_providers p;
select p.BLOCKED_HOURS, p.MIN_INTERVAL, SUM(p.MIN_INTERVAL) over(order by p.blocked_hours) from ap_providers p;
select p.BLOCKED_HOURS, p.MIN_INTERVAL, SUM(p.MIN_INTERVAL) over(order by p.blocked_hours, p.MIN_INTERVAL desc) from ap_providers p;
select p.BLOCKED_HOURS, p.MIN_INTERVAL, SUM(p.MIN_INTERVAL) over(partition by p.min_interval order by p.blocked_hours) from ap_providers p;

select sour, prov, state, count(state) over (partition by sour ) from temp5 t order by sour, prov;
select sour, prov, state, count(state) over (partition by sour order by sour) from temp5 t;
select sour, prov, state, count(state) over (partition by sour order by sour, prov) from temp5 t;

--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------

/*Analytic Functions: FIRST_VALUE, LAST_VALUE, LAG, LEAD
CUME_DIST
PERCENT_RANK
PERCENTILE_CONT
PERCENTILE_DISC */
SELECT BusinessEntityID, YEAR(QuotaDate) AS SalesYear, SalesQuota AS CurrentQuota,   
    LEAD(SalesQuota, 1,0) OVER (ORDER BY YEAR(QuotaDate)) AS NextQuota  
FROM Sales.SalesPersonQuotaHistory  

--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------

/*RANGING
Keywords: Preceding, Following, Unbounded, Current
UNBOUNDED PRECEDING - the first row in the frame
CURRENT ROW
BETWEEN AND
UNBOUNDED FOLLOWING - the last row in the frame

*/
select sour, prov, state, count(state) over (partition by sour rows current row) from temp5 t;
select sour, prov, state, sum(state) over (partition by sour order by sour range current row) from temp5 t;
select sour, prov, state, sum(state) over (partition by sour order by sour rows between current row and 2 following) from temp5 t;
SELECT *, LAST_VALUE(SalesQuota) over (partition by format(QuotaDate, 'yyyy-MM') order by QuotaDate)
, FIRST_VALUE(SalesQuota) over (partition by MONTH(QuotaDate), YEAR(QuotaDate) order by QuotaDate)
, LAST_VALUE(SalesQuota) over (partition by MONTH(QuotaDate), YEAR(QuotaDate) order by QuotaDate)
FROM Sales.SalesPersonQuotaHistory  
order by QuotaDate
--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------


/*Perfomance:
Table Spool - means using TempDB (so it can be optimazed)
Windows Spool - doesn't mean specific TempDB or Memory, need to be investigated by statistic IO*/

begin

	set statistics io on;

	select s.CustomerID
	, s.SalesOrderID
	, s.OrderDate
	, s.TotalDue
	, sum(s.TotalDue) over (order by s.salesorderid) running_total --using ranges
	from sales.SalesOrderHeader s
	order by s.SalesOrderID;
	/*(31465 rows affected)
	Table 'Worktable'. Scan count 31466, logical reads 189931 - it means using TempDB
	Table 'SalesOrderHeader'. Scan count 1, logical reads 689 */


	select s.CustomerID
	, s.SalesOrderID
	, s.OrderDate
	, s.TotalDue
	, sum(s.TotalDue) over (order by s.salesorderid rows unbounded preceding ) running_total --using frames, all rows up untill the current rows
	from sales.SalesOrderHeader s
	order by s.SalesOrderID;
	/*(31465 rows affected)
	Table 'Worktable'. Scan count 0, logical reads 0 --using Memory instead of TempDB
	Table 'SalesOrderHeader'. Scan count 1, logical reads 689 */


	select s.CustomerID
	, s.SalesOrderID
	, s.OrderDate
	, s.TotalDue
	, sum(s.TotalDue) over (order by s.salesorderid range unbounded preceding ) running_total --using ranges, all rows up untill the current rows
	from sales.SalesOrderHeader s
	order by s.SalesOrderID;
	/*(31465 rows affected)
	Table 'Worktable'. Scan count 31466, logical reads 189931 - it means using TempDB
	Table 'SalesOrderHeader'. Scan count 1, logical reads 689 */

end;


begin
	select p.PurchaseOrderID
	, p.PurchaseOrderDetailID
	, p.ProductID
	, p.LineTotal
	, '            ' empty_row
	, sum(p.LineTotal) over (order by p.PurchaseOrderID) sum_total --if we order only by PurchaseOrderID the result in sum_total will be inaccurate (check lines 2-3)
	, sum(p.LineTotal) over (order by p.PurchaseOrderID, p.PurchaseOrderDetailID) sum_total_correct
	, sum(p.LineTotal) over (order by p.PurchaseOrderID rows unbounded preceding) sum_total_correct
	, sum(p.LineTotal) over (order by p.PurchaseOrderID range unbounded preceding) sum_total_incorrect --incorrect
	from Purchasing.PurchaseOrderDetail p
	order by p.PurchaseOrderID, p.PurchaseOrderDetailID
end;





