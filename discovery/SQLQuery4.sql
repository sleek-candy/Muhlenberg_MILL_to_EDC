

-- this is one gift broken with jntkey
select	giftjntkey,giftkey,giftallkey,gifttype,giftamount
from	MuhlMillProd..gifts 
where	giftallkey in ('549600','549599')
ftallkey
from	MuhlMillProd..gifts g
where	exists (select 1 from MuhlMillProd..gifts x where x.gifthnrkey=g.giftkey and x.giftplgkey>5000)
and		g.gifttype='g'