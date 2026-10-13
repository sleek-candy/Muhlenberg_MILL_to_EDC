
-- find complicated gifts
select	count(*),giftallkey 
from	MuhlMillProd..gifts g
where	gifttype not like '%v'
and		gifttype not like '%j'
and		giftjntkey>0
group by giftallkey
having count(*)>1


-- general gift query overview
select	giftkey, giftallkey, giftplgkey, gifthnrkey,giftjntkey,
		giftmtchky, giftcrdkey, giftsumkey, giftlnkkey,
		giftamount, giftjntamt, gifttotal, gifttpledg,
		giftid, giftprocdt,gifttender,giftcamp,giftrest
from	MuhlMillProd..gifts g
where	giftallkey=511400
or		giftkey in (511399,511401,511400,511402)