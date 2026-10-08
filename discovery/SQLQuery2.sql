
select	count(*), gifttype
from	MuhlMillProd..gifts
where	gifttype not like '%j'
and		gifttype not like '%v'
group by gifttype
order by 1 desc

