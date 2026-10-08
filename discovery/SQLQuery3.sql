

select	count(*), gifttype
from	MuhlMillProd..gifts
where	gifttype not like '%j'
and		gifttype not like '%v'
and		giftallkey <> giftkey
group by gifttype
order by 1 desc

-- transactions will rollup 
select	g.giftallkey,gt.totalgiftamt
from	MuhlMillProd..gifts g
join	(select giftallkey, sum(giftamount) as totalgiftamt from MuhlMillProd..gifts where gifttype='g' group by giftallkey)gt on g.giftallkey=gt.giftallkey 
where	g.giftallkey = g.giftkey
and		g.gifttype='g'

select	giftjntkey,giftkey,giftallkey,gifttype,giftamount
from	MuhlMillProd..gifts 
where	giftjntkey>5000
and		giftkey<>giftallkey

