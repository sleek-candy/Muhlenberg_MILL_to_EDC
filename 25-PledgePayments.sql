
/***************************************************************************************
        PURPOSE:    Populate the pledge payment transactions
       DATABASE:    MUHLMILLPROD
         AUTHOR:    C.Hamblin
         CLIENT:    MUHLENBERG
  COPYRIGHT NOTICE: ALL SCRIPTS AND OTHER GENERATED CODE IS THE PROPERTY OF SLEEK CONSULTING LLC
                    TO BE USED FOR THE SOLE PURPOSED OF MIGRATING LEGACY MILLENNIUM DATA TO 
                    SALESFORCE EDUCATION CLOUD. CODE SHARING AMONG INSTITUTIONS MUST BE APPROVED
                    BY SABRE LEEK. THANK YOU FOR YOUR COOPERATION. COPYRIGHT 2026.

   SCRIPT PURPOSE:
        GiftTransaction
		GiftTransactionDesignation
		GiftSoftCredit

 SCRIPT HISTORY:
 ------------------------------------------------------------------------------------------------
   CH  09-14-2026:  Original version

*************************************************************************************************/
Use SleekConversion;

--================================================================================================
-- PART ONE: localize pledge payment gifts
--================================================================================================

-->> create localized outright gifts table
drop table if exists mu_outrightgifts;
select	giftallkey as xid, 
		giftkey, giftallkey, giftplgkey, giftjntkey,
		giftmtchky, giftcrdkey, giftsumkey, giftlnkkey,
		gifthnrkey, gifthnrmkr,
		giftamount, giftjntamt, gifttotal, gifttpledg,
		giftid, giftprocdt,gifttender,giftcamp,giftrest
into	mu_outrightgifts
from	MuhlMillProd..gifts g
where	not exists (select 1 from MuhlMillProd..gifts x where x.gifthnrkey=g.giftkey and x.giftplgkey>5000)
and		gifttype='g'
and		giftjntkey in (1,0)
union
select	o.giftallkey as xid, 
		g.giftkey, g.giftallkey, g.giftplgkey, g.giftjntkey,
		g.giftmtchky, g.giftcrdkey, g.giftsumkey, g.giftlnkkey,
		g.gifthnrkey, g.gifthnrmkr,
		g.giftamount, g.giftjntamt, g.gifttotal, g.gifttpledg,
		g.giftid, g.giftprocdt,g.gifttender,g.giftcamp,g.giftrest
from	MuhlMillProd..gifts g
join	MuhlMillProd..gifts o on g.giftjntkey=o.giftkey
where	not exists (select 1 from MuhlMillProd..gifts x where x.gifthnrkey=g.giftkey and x.giftplgkey>5000)
and		g.gifttype='g'
and		g.giftjntkey >5000;

select	* from mu_outrightgifts where xid=549599;
