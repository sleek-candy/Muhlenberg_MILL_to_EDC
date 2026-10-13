
select		count(*), pkey 
from (
select		g.giftkey as pkey, s.giftkey as lnkkey, s.giftrest as desg, g.giftkey as orig_allkey, 'pe' as gtype
--into		Pledge_Links
from		MuhlMillProd..gifts g
join		MuhlMillProd..gifts s on s.giftallkey = g.giftkey and rtrim(s.gifttype) in ('p', 'e', 'mp')
where		rtrim(g.gifttype) in ('p', 'e', 'mp') and g.giftallkey = g.giftkey )x
group by pkey
having count(*)>1


select		g.giftkey as pkey, s.giftkey as lnkkey, s.giftrest as desg, g.giftkey as orig_allkey, 'pe' as gtype, s.giftamount, s.giftamtplg
--into		Pledge_Links
from		MuhlMillProd..gifts g
join		MuhlMillProd..gifts s on s.giftallkey = g.giftkey and rtrim(s.gifttype) in ('p', 'e', 'mp')
where		rtrim(g.gifttype) in ('p', 'e', 'mp') and g.giftallkey = g.giftkey 
and			g.giftkey=259466


select		*
from		muhlmillprod..payments 
where		paylinkkey in (259466,259468)

select	*
from	MuhlMillProd..fieldlst 
where	table_name='gifts'
and		(column_name like '%key' or column_name like '%ky')