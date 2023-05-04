/*в SQL Server есть тип данных XML, т.о. мы можем использовать XML формат в колонках, переменных и параметрах
можно создать объект "коллекция XML-схем" и поместить в него схемы, 
на соответствие которым будет идти порверка при загрузке XML-данных на сервер 
*/

--XML-схема:
<?xml version="1.0" encoding="utf-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="country">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="country_name" type="xs:string"/>
        <xs:element name="population" type="xs:decimal"/>
      </xs:sequence>
    </xs:complexType>
  </xs:element>
</xs:schema>

--XML-документ, соответствующий данной схеме:
<?xml version="1.0" encoding="utf-8"?>
<country>
    <country_name>France</country_name>
    <population>59.7</population>
</country>

----------------------------------------------------------------------------------------
--создание коллекции XML-схем

create xml schema collection dbo.test_shm
as 
'<?xml version="1.0" encoding="utf-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="country">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="country_name" type="xs:string"/>
        <xs:element name="population" type="xs:decimal"/>
      </xs:sequence>
    </xs:complexType>
  </xs:element>
</xs:schema>';

select * from sys.xml_schema_collections
select * from sys.xml_schema_namespaces

drop xml schema collection dbo.test_shm

/*типизированный XML - проверяется на соответствие отпределенной схеме
нетипизированный XML - не проверятся на соответствие отпределенной схеме (т.к. это может дать высокую нагрузку на сервер)

документ XML - один корневой узел
фрагментX XML - мб несколько корневых узлов

*/
--создание таблицы колонкой типа XML и с проверкой данного поля на соответствие XML схеме
drop table if exists temp_1;

create table temp_1 (id int identity(1,1),
my_xml_fragment xml null, --нетипизированный XML
my_xml_fragment_check xml (content dbo.test_shm) null, --типизированный XML, возможна вставка фрагментов
my_xml_document_check xml (document dbo.test_shm) null, --типизированный XML, невозможна вставка фрагментов
) 

--вставка некорректного XML
insert into temp_1 (my_xml_fragment) --error
values ('<invalid data'); 

--вставка фрагмента XML
insert into temp_1 (my_xml_fragment) --ok
values ('<country_name>France</country_name>
		<population>59.7</population>'); 

--вставка документа XML
insert into temp_1 (my_xml_fragment) --ok
values ('<country>
			<country_name>France</country_name>
		</country>');

----------------------------------------------------------------------------------------
--вставка фрагмента XML с проверкой на соответствие схеме XML
insert into temp_1 (my_xml_fragment_check) --error
values ('<country_name>France</country_name>
		<population>59.7</population>'); 

--вставка документа XML с проверкой на соответствие схеме XML
insert into temp_1 (my_xml_fragment_check) --error
values ('<country>
			<country_name>France</country_name>
		</country>');

--вставка документа XML с проверкой на соответствие схеме XML
insert into temp_1 (my_xml_fragment_check) --error
values ('<country>
			<country_name>France</country_name>
			<population>59.7</population>
			<capital>Paris</capital>
		</country>'); 

--вставка документа XML с проверкой на соответствие схеме XML
insert into temp_1 (my_xml_fragment_check) --ok
values ('<country>
			<country_name>France</country_name>
			<population>59.7</population>
		</country>'); 

--вставка нескольких XML с проверкой на соответствие схеме XML
insert into temp_1 (my_xml_fragment_check) --ok
values ('<country>
			<country_name>France</country_name>
			<population>59.7</population>
		</country>
		<country>
			<country_name>UK</country_name>
			<population>37</population>
		</country>'); 

----------------------------------------------------------------------------------------
--вставка документа XML с проверкой на соответствие схеме XML
insert into temp_1 (my_xml_document_check) --ok
values ('<country>
			<country_name>France</country_name>
			<population>59.7</population>
		</country>'); 

--вставка нескольких XML с проверкой на соответствие схеме XML
insert into temp_1 (my_xml_document_check) --error
values ('<country>
			<country_name>France</country_name>
			<population>59.7</population>
		</country>
		<country>
			<country_name>UK</country_name>
			<population>37</population>
		</country>'); 




/*по аналогии и с переменными*/
DECLARE @tipXML xml (dbo.test_shm);  
DECLARE @intipXML xml;

set  @intipXML = --OK
	'<country_name>France</country_name>
	<population>59.7</population>'

select @intipXML;

set  @tipXML = --ERROR
	'<country_name>France</country_name>
	<population>59.7</population>'

select @tipXML;

set  @tipXML = --OK
	'<country>
		<country_name>France</country_name>
		<population>59.7</population>
	</country>'

select @tipXML;


/*XML indexes*/
/*существует 4 типа индексов XML
Primary XML index - создает дерево объетов, для его построения необходим clustered primary key на таблице
Secondary XML index PATH
Secondary XML index VALUE
Secondary XML index PROPERTY
*/
select * from temp_1

alter table temp_1 add constraint PK_test primary key clustered (id);

create primary xml index XI_test on temp_1(my_xml_fragment_check);

create xml index XI_test_value on temp_1(my_xml_fragment_check)
using xml index XI_test
for value;

select * from sys.xml_indexes




/*from table to XML*/
/*элементы
атрибуты
тэги

по умолчанию данные возвращаются как тип данных varchar а не как XML 
чтобы вернуть тип данных XML нужно исп. параметр TYPE
*/

create table #temp_c (id int identity, car varchar(20), model varchar(20), price int);
insert into #temp_c values 
('1', 'granta', 5000),
('1', 'x-ray', 8000),
('1', 'largus', 7000),
('2','srl', 50000),
('2','A 100', 20000),
('2','s 500', 80000),
('3', 'focus', 15000),
('4', 'kodiaq',20000),
('4', 'fadia',20000)

create table #temp_m (id int, [name] varchar(20))
insert into #temp_m values
(1,'lada'),
(2,'mercedes'),
(3,'ford'),
(4,'skoda')

select * from #temp_c
drop table #temp_c

--1. FOR XML RAW
/*в этом режиме каждая строка из возвращенного набора строк предобразуется в 1 элемент с имменем row,
а столбцы преобразуются в атрибуты этого элемента*/

select model,price fff from #temp_c where price > 20000
FOR XML RAW

			<row model="srl" price="50000" />
			<row model="s 500" price="80000" />

select model,price from #temp_c where price > 20000
FOR XML RAW ('Car') --переименование элемента row
, ELEMENTS --представление полей как элементов, а не атрибутов
, ROOT ('Cars') --определяем корневой элемент

			<Cars>
			  <Car>
				<model>srl</model>
				<price>50000</price>
			  </Car>
			  <Car>
				<model>s 500</model>
				<price>80000</price>
			  </Car>
			</Cars>

select model,price from #temp_c where price > 20000
FOR XML RAW ('Car') --переименование элемента row
, ELEMENTS --представление полей как элементов, а не атрибутов
, ROOT ('Cars') --определяем корневой элемент
, TYPE --возвращает тип данных XML, а не nvarchar

WITH XMLNAMESPACES('TEST' as ttt) --протранство имен
select [ttt:mytable].model as [ttt:model]
	, [ttt:mytable].price as [ttt:price]
from #temp_c as [ttt:mytable] where price > 20000
FOR XML RAW ('Car') --переименование элемента row
, ELEMENTS --представление полей как элементов, а не атрибутов
, ROOT ('Cars') --определяем корневой элемент
, TYPE --возвращает тип данных XML, а не nvarchar

select model,price from #temp_c where price > 20000
FOR XML RAW 
, XMLDATA

select model,price from #temp_c where price > 20000
FOR XML RAW 
, XMLSCHEMA  

select model,price from #temp_c where price > 20000
FOR XML RAW 
, XMLSCHEMA ('urn:example.com')  

select model,price from #temp_c where price > 20000
FOR XML RAW ,
BINARY BASE64

--все параметры
WITH XMLNAMESPACES('TEST' as ttt) --протранство имен
select [ttt:mytable].car as [ttt:car]
	, [ttt:mytable].model as [ttt:model]
	, [ttt:mytable].price as [ttt:price]
from #temp as [ttt:mytable] where price > 20000
FOR XML RAW ('Car')
, ELEMENTS XSINIL
, ROOT ('Cars')
, TYPE
, BINARY BASE64
, XMLDATA
, XMLSCHEMA  


--2. FOR XML AUTO
/*в этом режиме XML атовматически формируетсяна основе соединения таблиц*/

select firm.name, car.model car_model, car.price min_price --псевдонимы полей отпределяют название атрибутов
from #temp_c car --псевдонимы таблиц отпределяют название элементов
join #temp_m firm --псевдонимы таблиц отпределяют название элементов
	on car.car = firm.id
where car.price > 10000
order by firm.name, car.model
FOR XML AUTO
, ROOT ('Cars')
, ELEMENTS --представление полей как элементов, а не атрибутов
 XSINIL --если значение атбрибута NULL, то он все равно будет в документе


WITH XMLNAMESPACES('TEST' as ttt) --протранство имен
select [ttt:mytable].car as [ttt:car]
	, [ttt:mytable].model as [ttt:model]
	, [ttt:mytable].price as [ttt:price]
from #temp as [ttt:mytable] where price > 10000
order by [ttt:car] , [ttt:model]
FOR XML AUTO
, ELEMENTS
, ROOT ('Cars') --определяем корневой элемент



--3. FOR XML EXPLICIT
/*большой контроль для вывода XML, можно явно задавать порядок следования атрибутов
но довольно сложный: ElementName!TagNumber!AttributeName!Directive  */

--это аналог режима AUTO 
select 1 tag, null parent,
	firm.name [firm!1!name], 
	null [car!2!car_model],
	null [car!2!min_price]
from #temp_c car 
join #temp_m firm 
	on car.car = firm.id
where car.price > 10000
union
select 2 tag, 1 parent,
	firm.name [firm!1!name], 
	car.model [car!2!car_model],
	car.price [car!2!min_price]
from #temp_c car 
join #temp_m firm 
	on car.car = firm.id
where car.price > 10000
order by [firm!1!name],[car!2!car_model]
FOR XML EXPLICIT
, ROOT ('Cars') --определяем корневой элемент



--4. FOR XML PATH
--используется режим XPath: @ - атрибут, для элемента просто пишем псевдоним столбца

--это аналог режима AUTO, но без группировки по элементу firm
select firm.name '@name',
car.model 'car/@car_model',
car.price 'car/@min_price' 
from #temp_c car 
join #temp_m firm 
	on car.car = firm.id
where car.price > 10000
order by firm.name
FOR XML path ('firm')
, ROOT ('Cars') --определяем корневой элемент







select column_nm.query('/book[@id = "bk"]') from tabl












create table #tabl (id varchar(10), val int);
insert into #tabl values
('a',1),
('b',2),
('c',NULL),
('d',1),
('e',NULL),
('a',NULL),
('c',1),
('b',4),
('a',3)

select * from #tabl order by 1


select id,val from #tabl order by 1 for xml auto;
select val from #tabl order by 1 for xml auto;
select val from #tabl order by 1 for xml path('');
select val from #tabl order by 1 for xml path('element');

select ','+ cast(val as varchar(10))
from #tabl t1 
where t1.id = 'a' 
order by 1 
for xml path('')

select distinct t2.id, 
stuff((select ','+ cast(val as varchar(10))
		from #tabl t1 
		where t1.id = t2.id
		order by 1
		for xml path('')),1,1,'') 
from #tabl t2;

select * from #tabl order by 1

--результат
--a	1,3
--b	2,4
--c	1
--d	1
--e	NULL


with xml_tab as (select distinct val2, 
stuff((select ','+cast(ololo as varchar(3)) 
	from temp2 t1 
	where t1.val2 = t2.val2 
	order by 1 
	for xml path('')),1,1,'') list
from temp2 t2),
cnt_tab as (
select t1.val2, count(t1.ololo) cnt
from temp2 t1
group by t1.val2)
select c.val2, c.cnt, x.list
from cnt_tab c
inner join xml_tab x
on c.val2 = x.val2
order by 1

select *, (select 10) from temp2




select distinct LETTER, 
stuff((select ','+cast(new as varchar(2)) 
	from temp4 t1 
	where t1.LETTER = t2.LETTER 
	order by 1 
	for xml path('')),1,1,'') list
from temp4 t2
where LETTER = 'B'