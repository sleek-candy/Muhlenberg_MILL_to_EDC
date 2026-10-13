

-- this is one gift broken with jntkey
select	giftjntkey,giftkey,giftallkey,gifttype,giftamount
from	MuhlMillProd..gifts 
where	giftallkey in ('549600','549599')

-- remove these if pulling only outright gifts
select	giftallkey, giftkey, giftjntkey, 
from	MuhlMillProd..gifts g
where	g.gifttype='g'
and		not exists (select 1 from MuhlMillProd..gifts x where x.gifthnrkey=g.giftkey and x.giftplgkey>5000)
