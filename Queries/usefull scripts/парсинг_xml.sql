declare @xml xml
set @xml = 
'<Root>



</Root>'
select 
	b.n.value('(PHONE_NO)[1]', 'varchar(38)') as ph_no,
	b.n.value('(PROVIDER_ID)[1]', 'int') as prov_id,
	b.n.value('(PROVIDERD_ID)[1]', 'int') as provd_id
	into #xmltableq
	from @xml.nodes('/Root/body') b(n)


select * from #xmltableq
where ph_no = '93700' or ph_no = '95392'

select distinct client_id from reqwest ar with(nolock) right join #xmltableq xtq	ON ar.client_id=xtq.ph_no
where REQWEST_SOURCE = 11 and
 type = 1
and (state = 6 or state=5) 
and dates between DATEPART(month,getdate()-2) and getdate()
and ar.client_id in (
select client_id from reqwest with(nolock)
where reqwest_source = 7 and client_id in (
select client_id from (
select client_id 'client_id', reqwest_source 'rso', dates
from reqwest ar with(nolock) 
where client_id = client_id
--and provider_id = 5
and type = 1
and state = 7
and dates between DATEPART(month,getdate()-2) and getdate()
) as tableq1
group by client_id
having count(client_id)>1)
and dates in (
select max(dates) as datta from (
select client_id 'client_id', reqwest_source 'rso', dates
from reqwest ar with(nolock) 
where client_id = client_id
and type = 1
and state = 7
and dates between DATEPART(month,getdate()-2) and getdate()
) as tableq1
group by client_id
having count(client_id)>1))


-- номера, которые есть в БД
select ph_no from #xmltableq
where ph_no in (select distinct phone_number from auto)

--номера, по которым есть MNP
select ph_no from #xmltableq
where ph_no in (select distinct client_id from reqwest
where reqwest_source = 11 and type = 1)