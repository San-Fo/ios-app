#!/usr/bin/env python3
"""Seed a VARIED set of Hong Kong businesses that showcase every cause / goal
the app supports, across every backend category. Pushes to the real server via
the public API. Demo-data tool only; does not touch app code.

Goals showcased (financialIntent + sale lifecycle):
  - sale            : commercial acquisition (AI-evaluated) with seeded bids
  - revenueShareLoan: revenue-share financing for commercial investors
  - donation        : community donation campaign with reward tiers
  - retail_fallback : a sale that the owner declined to commercial bidders and
                      opened to the public (outright purchase + group takeover),
                      with a real takeover group created and joined

Categories used: restaurant, cafe, retail, services, wellness, artsAndCrafts.

Usage:
    python3 scripts/seed_varied.py [--base URL] [--dry-run]
"""
from __future__ import annotations

import argparse
import json
import random
import sys
import time
import urllib.error
import urllib.request

DEFAULT_BASE = "https://lbi.proxied.zone/api/v1"

VALID_DISTRICTS = {
    "central", "centralWestern", "wanChai", "causewayBay", "eastern",
    "shamShuiPo", "mongKok", "yauMaTei", "yauTsimMong", "tsimShaTsui",
    "kowloonCity", "kwunTong", "shauKeiWan", "tinHau", "saiYingPun",
    "taiPo", "shaTin", "tuenMun",
}

IMAGES = {
    "restaurant": [
        "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4",
        "https://images.unsplash.com/photo-1552566626-52f8b828add9",
        "https://images.unsplash.com/photo-1592861956120-e524fc739696",
    ],
    "cafe": [
        "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085",
        "https://images.unsplash.com/photo-1453614512568-c4024d13c247",
        "https://images.unsplash.com/photo-1442512595331-e89e73853f31",
    ],
    "retail": [
        "https://images.unsplash.com/photo-1441986300917-64674bd600d8",
        "https://images.unsplash.com/photo-1604719312566-8912e9227c6a",
        "https://images.unsplash.com/photo-1481437156560-3205f6a55735",
    ],
    "services": [
        "https://images.unsplash.com/photo-1521590832167-7bcbfaa6381f",
        "https://images.unsplash.com/photo-1581092580497-e0d23cbdf1dc",
        "https://images.unsplash.com/photo-1530124566582-a618bc2615dc",
    ],
    "wellness": [
        "https://images.unsplash.com/photo-1544161515-4ab6ce6db874",
        "https://images.unsplash.com/photo-1540497077202-7c8a3999166f",
        "https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b",
    ],
    "artsAndCrafts": [
        "https://images.unsplash.com/photo-1513519245088-0e12902e5a38",
        "https://images.unsplash.com/photo-1499781350541-7783f6c6a0c8",
        "https://images.unsplash.com/photo-1452860606245-08befc0ff44b",
    ],
}
IMG_PARAMS = "?auto=format&fit=crop&w=1200&q=70"

INVESTOR_NAMES = ["Harbourfront Capital", "K. Lai", "Lantau Ventures", "S. Wong", "Victoria Peak Partners"]
BID_MESSAGES = [
    "Committed to preserving the name, staff and recipes.",
    "Hands-off operator partnership; owner stays on.",
    "Clean books, loyal footfall — serious offer.",
    "We back independent HK businesses; open to earn-out terms.",
]
NEIGHBOURS = [
    ("varied-fan-01", "Ah Ming"), ("varied-fan-02", "Carmen Lau"),
    ("varied-fan-03", "Jacky Ho"), ("varied-fan-04", "Priya Nair"),
    ("varied-fan-05", "Mei Chan"), ("varied-fan-06", "Daniel Tse"),
]
MEMORIES = [
    "A neighbourhood institution — I grew up coming here.",
    "Would be heartbroken if this place ever disappeared.",
    "The owner treats every regular like family.",
    "Best in the district, hands down.",
    "Pooling in because places like this are worth saving.",
]

# (name, category, district, address, lat, lng, founded, goal, owner, bio, blurb)
SOURCE = [
    # --- SALE (commercial acquisition) ---
    ("Tai Ping Koon Diner", "restaurant", "central", "60 Stanley St, Central", 22.2826, 114.1546, 1965, "sale",
     "Lo Kin-Wah", "Second-generation owner of a Soy-sauce-Western institution.",
     "A beloved cha-chaan-teng-meets-Western diner seeking a steward to carry it forward."),
    ("Kowloon Cutlery Works", "retail", "shamShuiPo", "188 Apliu St, Sham Shui Po", 22.3309, 114.1626, 1972, "sale",
     "Chan Yiu-Tong", "Master knife-grinder running the family hardware shop.",
     "A legendary cutlery and hardware store ready for new ownership."),
    ("Pier 7 Seafood House", "restaurant", "shauKeiWan", "12 Tai Tam Rd, Shau Kei Wan", 22.2790, 114.2290, 1988, "sale",
     "Tsui Mei-Fong", "Runs the dockside kitchen her father opened.",
     "Dockside seafood restaurant with decades of regulars, open to acquisition."),

    # --- REVENUE-SHARE LOAN (commercial investor financing) ---
    ("Sai Wan Roasters", "cafe", "saiYingPun", "9 High St, Sai Ying Pun", 22.2856, 114.1430, 2016, "revenueShareLoan",
     "Ho Tsz-Wing", "Specialty roaster scaling a wholesale line.",
     "Profitable micro-roastery raising revenue-share financing to expand roasting capacity."),
    ("Lin's Physiotherapy", "wellness", "wanChai", "3 Spring Garden Ln, Wan Chai", 22.2748, 114.1735, 2014, "revenueShareLoan",
     "Lin Ka-Yiu", "Physiotherapist opening a second treatment room.",
     "Established clinic raising growth capital via revenue share to add capacity."),
    ("Mongkok Print Studio", "services", "mongKok", "30 Tung Choi St, Mong Kok", 22.3220, 114.1700, 2011, "revenueShareLoan",
     "Yip Chun-Kit", "Risograph & letterpress printer for local artists.",
     "Boutique print studio seeking revenue-share funding for a new press."),

    # --- DONATION (community support campaign) ---
    ("Tin Hau Herbal Hall", "wellness", "tinHau", "5 Tin Hau Temple Rd", 22.2820, 114.1920, 1958, "donation",
     "Auntie Sin", "Third-generation herbalist keeping old recipes alive.",
     "A heritage herbal hall raising community support to restore its century-old shopfront."),
    ("Wan Chai Letterpress", "artsAndCrafts", "wanChai", "18 Tai Wong St E, Wan Chai", 22.2760, 114.1730, 1969, "donation",
     "Master Kwan", "The last hand-typesetter in the district.",
     "Help preserve a vanishing craft — community donations keep the presses running."),
    ("Sham Shui Po Toy Repair", "services", "shamShuiPo", "44 Fuk Wing St", 22.3300, 114.1610, 1980, "donation",
     "Uncle Fai", "Fixes the toys three generations grew up with.",
     "A one-of-a-kind toy hospital seeking donations to stay open another decade."),
    ("Causeway Bay Bookbinders", "artsAndCrafts", "causewayBay", "7 Pak Sha Rd", 22.2789, 114.1841, 1974, "donation",
     "Ng Sai-Keung", "Hand-binds and restores antique books.",
     "A traditional bindery raising community funds to train an apprentice."),

    # --- RETAIL FALLBACK (declined commercial bids -> public + group takeover) ---
    ("Yau Ma Tei Tong Sui", "restaurant", "yauMaTei", "20 Temple St, Yau Ma Tei", 22.3130, 114.1700, 1979, "retail_fallback",
     "Poon Lai-Han", "Dessert-shop owner ready to pass on the wok.",
     "A famous tong-sui shop opened to the public and to a community group takeover."),
    ("Old Town Tailor", "services", "centralWestern", "33 Hollywood Rd, Sheung Wan", 22.2846, 114.1500, 1962, "retail_fallback",
     "Leung Po-Wah", "Bespoke tailor seeking a successor or a group of locals.",
     "A heritage tailoring house now open to a single buyer or a neighbourhood group."),
    ("Star Ferry Newsstand", "retail", "tsimShaTsui", "Star Ferry Pier, Tsim Sha Tsui", 22.2940, 114.1685, 1957, "retail_fallback",
     "Wong Tai-Sang", "Runs the pier's last newsstand and curio stall.",
     "An iconic pier kiosk opened to the public and to a community takeover group."),
]


class API:
    def __init__(self, base):
        self.base = base.rstrip("/")

    def req(self, method, path, body=None, token=None):
        url = f"{self.base}/{path}"
        data = json.dumps(body).encode() if body is not None else None
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        r = urllib.request.Request(url, data=data, headers=headers, method=method)
        last = None
        for attempt in range(4):
            try:
                with urllib.request.urlopen(r, timeout=30) as resp:
                    raw = resp.read().decode()
                    return resp.status, (json.loads(raw) if raw else {})
            except urllib.error.HTTPError as e:
                detail = e.read().decode()
                last = RuntimeError(f"{method} {path} -> {e.code}: {detail}")
                if e.code in (422, 500, 502, 503):
                    time.sleep(0.5 * (attempt + 1))
                    continue
                return e.code, detail
        raise last

    def login(self, subject, investor=None, name=None):
        body = {"subject": subject}
        if investor:
            body["investorStatus"] = investor
        if name:
            body["name"] = name
        return self.req("POST", "auth/dev", body)[1]["sessionToken"]

    def set_profile(self, token, name, bio):
        self.req("PATCH", "me", {"name": name, "biography": bio}, token)

    def create(self, token, body):
        _, res = self.req("POST", "businesses", body, token)
        return res.get("id") or res.get("_id") if isinstance(res, dict) else None


def gallery(category, i):
    pics = IMAGES.get(category, IMAGES["retail"])
    return [pics[(i + k) % len(pics)] + IMG_PARAMS for k in range(3)]


def intent_for(goal, asking):
    if goal in ("sale", "retail_fallback"):
        return {"sale": {"targetAmount": asking}}
    if goal == "revenueShareLoan":
        return {"revenueShareLoan": {"targetAmount": asking, "totalInterestPercentage": 8, "totalRevenueCutPercentage": 6}}
    return {"donation": {"tiers": [
        {"name": "Friend", "minAmount": 100},
        {"name": "Patron", "minAmount": 500},
        {"name": "Guardian", "minAmount": 2500},
    ]}}


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--base", default=DEFAULT_BASE)
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--seed", type=int, default=23)
    args = p.parse_args()

    random.seed(args.seed)
    api = API(args.base)
    print(f"Seeding {len(SOURCE)} varied businesses -> {args.base}\n")

    investors, fans = [], []
    if not args.dry_run:
        for nm in INVESTOR_NAMES:
            slug = nm.lower().replace(" ", "-").replace(".", "")
            investors.append((nm, api.login(f"varied-inv-{slug}", investor="institutionalVerified", name=nm)))
        for subj, nm in NEIGHBOURS:
            fans.append((nm, api.login(subj, name=nm)))

    created = []
    for i, (name, cat, dist, addr, lat, lng, founded, goal, owner, bio, blurb) in enumerate(SOURCE):
        assert dist in VALID_DISTRICTS, dist
        asking = 1_800_000 + i * 220_000
        body = {
            "name": name,
            "description": f"{blurb} Founded in {founded} by {owner}. {bio}",
            "foundingYear": founded,
            "categories": [cat],
            "district": dist,
            "address": addr,
            "latitude": lat,
            "longitude": lng,
            "galleryImageUrls": gallery(cat, i),
            "financialIntent": intent_for(goal, asking),
        }
        if args.dry_run:
            print(f"[{i+1:02d}] {name:28} {cat:13} {goal}")
            continue

        try:
            token = api.login(f"varied-owner-{i+1:02d}")
            api.set_profile(token, owner, bio)
            # Idempotent: reuse this owner's existing listing if a prior run
            # already created it (so re-running fixes shells instead of dupes).
            _, mine = api.req("GET", "me/businesses", None, token)
            existing = next((b for b in (mine if isinstance(mine, list) else [])
                             if b.get("name") == name), None)
            if existing:
                bid = existing.get("id") or existing.get("_id")
            else:
                bid = api.create(token, body)
            api.req("POST", f"businesses/{bid}/verify", {}, token)

            # Only submit the sale if one isn't already present (re-run safety).
            _, pre = api.req("GET", f"businesses/{bid}/sale", None, token)
            has_sale = isinstance(pre, dict) and pre.get("sale") is not None
            if goal in ("sale", "retail_fallback") and not has_sale:
                api.req("POST", f"businesses/{bid}/sale", {
                    "askingPrice": asking,
                    "financials": {"annualRevenue": int(asking * 0.8), "annualProfit": int(asking * 0.2),
                                   "monthlyRent": 40_000, "leaseYearsRemaining": 4, "staffCount": 4,
                                   "inventoryValue": 80_000, "notes": "Loyal regulars; established brand."},
                    "includes": ["Equipment", "Brand & goodwill", "Recipes"],
                    "ownerWillingToStay": True, "handoverMonths": 6,
                }, token)

            # Current sale state for bid/stage guards.
            _, scur = api.req("GET", f"businesses/{bid}/sale", None, token)
            sale_obj = scur.get("sale") if isinstance(scur, dict) else None
            existing_bids = (sale_obj or {}).get("bids") or []

            if goal == "sale" and not existing_bids:
                for b, (inv_name, inv_token) in enumerate(random.sample(investors, k=2)):
                    api.req("POST", f"businesses/{bid}/sale/bids",
                            {"amount": int(asking * (0.85 + 0.05 * b)), "message": random.choice(BID_MESSAGES)}, inv_token)

            stage = (sale_obj or {}).get("stage")
            if goal == "retail_fallback" and stage != "openToRetail":
                api.req("POST", f"businesses/{bid}/sale/decline-commercial-bids", {
                    "retailAskingPrice": int(asking * 0.95),
                    "allowOutrightPurchase": True,
                    "allowGroupTakeover": True,
                    "ownerNote": "I'd love to see locals take this on together.",
                }, token)
                # A neighbour starts a takeover group and others join.
                starter_name, starter = random.choice(fans)
                gstatus, gres = api.req("POST", f"businesses/{bid}/takeover-groups",
                                        {"name": f"Friends of {name}", "pledgeAmount": 50_000}, starter)
                if gstatus in (200, 201) and isinstance(gres, dict):
                    gid = gres.get("id") or gres.get("_id")
                    for jn, jt in random.sample(fans, k=3):
                        if jt != starter and gid:
                            api.req("POST", f"takeover-groups/{gid}/join", {"pledgeAmount": 30_000}, jt)

            # Memories + social proof. Skip memories if some already exist
            # (re-run safety so we don't pile up duplicates).
            _, cur = api.req("GET", f"businesses/{bid}", None, token)
            has_memories = isinstance(cur, dict) and bool(cur.get("memories"))
            if not has_memories:
                for jn, jt in random.sample(fans, k=random.randint(2, 4)):
                    api.req("POST", f"businesses/{bid}/memories", {"body": random.choice(MEMORIES)}, jt)
            for jn, jt in fans:
                api.req("POST", f"businesses/{bid}/like", {}, jt)  # server dedupes per user
                for _ in range(random.randint(1, 3)):
                    api.req("GET", f"businesses/{bid}", None, jt)

            created.append((name, goal, bid))
            print(f"[{i+1:02d}] OK  {name:28} {cat:13} {goal}  id={bid}")
        except Exception as exc:  # noqa: BLE001
            print(f"[{i+1:02d}] FAIL {name}: {exc}", file=sys.stderr)

    if not args.dry_run:
        by_goal = {}
        for _, g, _ in created:
            by_goal[g] = by_goal.get(g, 0) + 1
        print(f"\nDone. Created {len(created)}/{len(SOURCE)}: {by_goal}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
