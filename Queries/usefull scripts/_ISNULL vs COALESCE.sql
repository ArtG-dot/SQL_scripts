select * from temp;
select * from temp2;
select * from temp3;
select * from temp4;
alter table temp3 add num2 int;
insert into temp3 
values (2,NULL,10),
(3,NULL,10),
(4,2,NULL),
(5,2,NULL),
(6,2,NULL)

select *, ISNULL(3*num,num2) from temp3;
select *, coalesce(3*num,num2) from temp3;



declare @x char(3) = NULL, @y char(5) = '12345'; 
declare @z int = null, @w int = 12345; 


select coalesce(@x,@y),coalesce(@y,@x);
select ISNULL(@x,@y),ISNULL(@y,@x);

select len(coalesce(@x, @y)),len(coalesce(@y, @x));
select len(ISNULL(@x, @y)),len(ISNULL(@y, @x));

select coalesce('abc',123);
select coalesce(123,'abc');
select ISNULL('abc',123);
select coalesce(null,null);
select ISNULL(null,null);
select coalesce(cast(null as int),null);