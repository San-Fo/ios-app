#!/usr/bin/env python3
"""Second batch of demo businesses — more variety across every goal/option,
with rich content and varied progress. Pushes to the real server via the public
API. Demo tooling only; does not touch app code.

Each entry declares a `goal`:
  sale            -> commercial sale + some bids (partial interest)
  loan            -> revenue-share loan + verified-investor contributions
  donation        -> donation campaign + supporter contributions (tiers)
  retail          -> sale declined to public (outright purchase)
  takeover        -> sale declined to public + a community takeover group

Usage: python3 scripts/seed_batch2.py [--base URL] [--dry-run]
"""
from __future__ import annotations
import argparse, json, random, sys, time, urllib.error, urllib.request

DEFAULT_BASE = "https://lbi.proxied.zone/api/v1"

VALID_DISTRICTS = {
    "central","centralWestern","wanChai","causewayBay","eastern","shamShuiPo",
    "mongKok","yauMaTei","yauTsimMong","tsimShaTsui","kowloonCity","kwunTong",
    "shauKeiWan","tinHau","saiYingPun","taiPo","shaTin","tuenMun",
}

IMG = {
 "restaurant":"https://images.unsplash.com/photo-1552566626-52f8b828add9",
 "cafe":"https://images.unsplash.com/photo-1442512595331-e89e73853f31",
 "retail":"https://images.unsplash.com/photo-1441986300917-64674bd600d8",
 "services":"https://images.unsplash.com/photo-1581092580497-e0d23cbdf1dc",
 "wellness":"https://images.unsplash.com/photo-1544161515-4ab6ce6db874",
 "artsAndCrafts":"https://images.unsplash.com/photo-1513519245088-0e12902e5a38",
}
P="?auto=format&fit=crop&w=1200&q=70"

INVESTORS=["Aberdeen Capital","Y. Chow","Tsing Yi Partners","R. Mak","Repulse Bay Holdings"]
SUPPORTERS=[("b2-sup-01","Ivy Cheung"),("b2-sup-02","Ken Lo"),("b2-sup-03","Sara Ip"),
            ("b2-sup-04","Tom Yuen"),("b2-sup-05","Gigi Wan"),("b2-sup-06","Ben Chu"),
            ("b2-sup-07","Nina So"),("b2-sup-08","Alan Kwok")]
MEMORIES=["A real neighbourhood treasure.","My family has come here for years.",
 "Hope they stay open forever.","The owner is the kindest person on the street.",
 "Pooling in because places like this matter.","Worth every dollar — and every visit."]

# name, category, district, address, lat, lng, founded, goal, owner, bio
SRC=[
 ("Sham Shui Po Noodle King","restaurant","shamShuiPo","58 Kweilin St",22.3318,114.1599,1976,"sale",
   "Cheung Kwok-Keung","Hand-pulls noodles the way his master taught him."),
 ("Wan Chai Vinyl Den","retail","wanChai","14 Tai Yuen St",22.2772,114.1726,1989,"sale",
   "Eddie Lam","Keeper of Hong Kong's largest second-hand record wall."),
 ("Central Watch Hospital","services","central","22 Lyndhurst Terrace",22.2837,114.1542,1968,"sale",
   "Master Yuen","Repairs mechanical watches three generations have trusted."),
 ("Quarry Bay Climb Lab","wellness","eastern","8 King's Rd",22.2845,114.2120,2019,"loan",
   "Felix Ng","Built the bouldering gym the eastern district was missing."),
 ("Yau Ma Tei Soy Works","services","yauMaTei","41 Shanghai St",22.3122,114.1705,1955,"loan",
   "Auntie Mok","Stone-grinds soy milk and tofu before dawn each day."),
 ("Tai Po Farm Kitchen","restaurant","taiPo","3 Fu Shin St",22.4502,114.1701,2012,"loan",
   "Hana Lee","Farm-to-table set lunches from her family's New Territories plot."),
 ("Tin Hau Paper Offerings","artsAndCrafts","tinHau","9 Electric Rd",22.2825,114.1925,1962,"donation",
   "Uncle Tang","Folds paper offerings by hand for festivals and funerals."),
 ("Mong Kok Goldfish Stall","retail","mongKok","12 Tung Choi St",22.3210,114.1702,1971,"donation",
   "Lily Pang","Last of the Goldfish Street family stalls."),
 ("Sai Ying Pun Tea House","cafe","saiYingPun","88 Third St",22.2860,114.1440,1948,"donation",
   "Grandpa Sze","Pours gongfu tea the slow, proper way."),
 ("Stanley Sailmakers","artsAndCrafts","eastern","2 Stanley Main St",22.2188,114.2130,1959,"donation",
   "Capt. Ho","Stitches sails and canvas bags by hand."),
 ("Sheung Wan Spice Merchant","retail","centralWestern","19 Bonham Strand",22.2865,114.1505,1952,"retail",
   "Devi Sharma","Third-generation dried-spice and herb trader."),
 ("Kwun Tong Steel Bender","services","kwunTong","77 Hung To Rd",22.3125,114.2262,1981,"retail",
   "Brother Keung","Custom metalwork for HK's last factory tenants."),
 ("Sha Tin Dumpling House","restaurant","shaTin","6 Sha Tin Centre St",22.3820,114.1885,1990,"takeover",
   "Mama Fung","Her dumpling folds are a neighbourhood legend."),
 ("Tuen Mun Bicycle Doctor","services","tuenMun","30 Tsing Ho Square",22.3915,113.9772,1985,"takeover",
   "Sifu Wai","Has fixed every kid's bike in Tuen Mun for 40 years."),
 ("Kowloon City Thai Grocer","retail","kowloonCity","25 South Wall Rd",22.3302,114.1892,1994,"takeover",
   "Khun Som","Little Thailand's beloved corner grocer."),
]

class API:
    def __init__(s,b): s.base=b.rstrip("/")
    def req(s,m,p,body=None,tok=None,retries=5):
        url=f"{s.base}/{p}"; data=json.dumps(body).encode() if body is not None else None
        h={"Content-Type":"application/json"}
        if tok: h["Authorization"]=f"Bearer {tok}"
        last=None
        for a in range(retries):
            r=urllib.request.Request(url,data=data,headers=h,method=m)
            try:
                with urllib.request.urlopen(r,timeout=30) as resp:
                    raw=resp.read().decode(); return resp.status,(json.loads(raw) if raw else {})
            except urllib.error.HTTPError as e:
                d=e.read().decode(); last=RuntimeError(f"{m} {p} -> {e.code}: {d}")
                if e.code in (422,500,502,503): time.sleep(0.5*(a+1)); continue
                return e.code,d
        raise last
    def login(s,subj,investor=None,vstate=None,name=None):
        body={"subject":subj}
        if investor: body["investorStatus"]=investor
        if vstate: body["verificationState"]=vstate
        if name: body["name"]=name
        return s.req("POST","auth/dev",body)[1]["sessionToken"]

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--base",default=DEFAULT_BASE)
    ap.add_argument("--dry-run",action="store_true"); ap.add_argument("--seed",type=int,default=41)
    args=ap.parse_args(); random.seed(args.seed); api=API(args.base)
    print(f"Seeding {len(SRC)} businesses (batch 2) -> {args.base}\n")
    if args.dry_run:
        for r in SRC: print(f"  {r[0]:30} {r[1]:13} {r[7]}")
        return 0

    investors=[(n,api.login(f"b2-inv-{n.lower().replace(' ','-').replace('.','')}",
               investor="institutionalVerified",vstate="verified",name=n)) for n in INVESTORS]
    supporters=[(n,api.login(subj,name=n)) for subj,n in SUPPORTERS]

    created=[]
    for i,(name,cat,dist,addr,lat,lng,founded,goal,owner,bio) in enumerate(SRC):
        assert dist in VALID_DISTRICTS, dist
        asking=1_900_000+i*180_000; target=600_000+i*40_000
        if goal in ("sale","retail","takeover"): intent={"sale":{"targetAmount":asking}}
        elif goal=="loan": intent={"revenueShareLoan":{"targetAmount":target,"totalInterestPercentage":8,"totalRevenueCutPercentage":5}}
        else: intent={"donation":{"tiers":[{"name":"Friend","minAmount":100},{"name":"Patron","minAmount":500},{"name":"Guardian","minAmount":2500}]}}
        body={"name":name,"description":f"{bio} Founded in {founded} by {owner}.","foundingYear":founded,
              "categories":[cat],"district":dist,"address":addr,"latitude":lat,"longitude":lng,
              "galleryImageUrls":[IMG[cat]+P],"financialIntent":intent}
        try:
            tok=api.login(f"b2-owner-{i+1:02d}")
            api.req("PATCH","me",{"name":owner,"biography":bio},tok)
            res=api.req("POST","businesses",body,tok)[1]
            bid=res.get("id") or res.get("_id")
            api.req("POST",f"businesses/{bid}/verify",{},tok)

            if goal in ("sale","retail","takeover"):
                api.req("POST",f"businesses/{bid}/sale",{"askingPrice":asking,
                  "financials":{"annualRevenue":int(asking*0.8),"annualProfit":int(asking*0.2),
                   "monthlyRent":40000,"leaseYearsRemaining":4,"staffCount":4,"inventoryValue":80000,
                   "notes":"Loyal regulars; established brand."},
                  "includes":["Equipment","Brand & goodwill","Recipes"],"ownerWillingToStay":True,"handoverMonths":6},tok)

            if goal=="sale":
                for b,(inv,it) in enumerate(random.sample(investors,k=random.randint(1,3))):
                    api.req("POST",f"businesses/{bid}/sale/bids",
                      {"amount":int(asking*(0.78+0.05*b)),"message":"Committed to keeping it local."},it)

            if goal=="loan":
                for amt,(inv,it) in zip([120000,90000,70000],investors):
                    api.req("POST",f"businesses/{bid}/actions",{"kind":"revenueShareLoan","amount":amt},it)

            if goal=="donation":
                for amt,(sn,st) in zip([2500,1000,500,300,200],supporters):
                    tier="Guardian" if amt>=2500 else "Patron" if amt>=500 else "Friend"
                    api.req("POST",f"businesses/{bid}/actions",{"kind":"donation","amount":amt,"tier":tier},st)

            if goal in ("retail","takeover"):
                api.req("POST",f"businesses/{bid}/sale/decline-commercial-bids",
                  {"retailAskingPrice":int(asking*0.95),"allowOutrightPurchase":True,
                   "allowGroupTakeover":(goal=="takeover"),
                   "ownerNote":"Open to locals taking this on."},tok)
            if goal=="takeover":
                sn,st=supporters[0]
                _,g=api.req("POST",f"businesses/{bid}/takeover-groups",{"name":f"Friends of {name}","pledgeAmount":50000},st)
                gid=g.get("id") or g.get("_id") if isinstance(g,dict) else None
                for n2,t2 in supporters[1:random.randint(3,6)]:
                    if gid: api.req("POST",f"takeover-groups/{gid}/join",{"pledgeAmount":35000},t2)

            # memories + likes/views for everyone
            for sn,st in random.sample(supporters,k=random.randint(2,4)):
                api.req("POST",f"businesses/{bid}/memories",{"body":random.choice(MEMORIES)},st)
            for sn,st in supporters:
                api.req("POST",f"businesses/{bid}/like",{},st)
                for _ in range(random.randint(1,3)): api.req("GET",f"businesses/{bid}",None,st)

            created.append((name,goal)); print(f"[{i+1:02d}] OK  {name:30} {cat:13} {goal}  id={bid}")
        except Exception as e:
            print(f"[{i+1:02d}] FAIL {name}: {e}",file=sys.stderr)

    byg={}
    for _,g in created: byg[g]=byg.get(g,0)+1
    print(f"\nDone. Created {len(created)}/{len(SRC)}: {byg}")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
