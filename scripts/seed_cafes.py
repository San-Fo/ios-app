#!/usr/bin/env python3
"""Generate rich, artificial cafe/coffee store listings (inspired by scraped
Google Places data) and push them to the LBI backend via the public API.

Mock-data quality, but on the real server. For each business it:
  1. creates a dedicated dev owner account with a real name + biography
     (POST /auth/dev, PATCH /me),
  2. creates the business (POST /businesses) with a founder-story description,
     district, gallery images and a financial intent,
  3. verifies it so it appears in search/recommended (POST .../verify),
  4. for `sale` listings, submits the professional sale (auto AI-evaluated) and
     seeds a couple of commercial bids from verified investors,
  5. seeds social proof: likes from several other users + view counts.

The backend has NO endpoint for community memories/comments/reviews (404), so
neighbourhood voices are woven into the description instead (the app derives
"what locals say" from the listing text).

Usage:
    python3 scripts/seed_cafes.py [--base URL] [--dry-run]

Seeding/demo-data tool only. Does not touch the app codebase.
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

COFFEE_IMAGES = [
    "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085",
    "https://images.unsplash.com/photo-1453614512568-c4024d13c247",
    "https://images.unsplash.com/photo-1442512595331-e89e73853f31",
    "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb",
    "https://images.unsplash.com/photo-1521017432531-fbd92d768814",
    "https://images.unsplash.com/photo-1559496417-e7f25cb247f3",
    "https://images.unsplash.com/photo-1554118811-1e0d58224f24",
    "https://images.unsplash.com/photo-1509042239860-f550ce710b93",
    "https://images.unsplash.com/photo-1525610553991-2bede1a236e2",
    "https://images.unsplash.com/photo-1490818387583-1baba5e638af",
    "https://images.unsplash.com/photo-1498804103079-a6351b050096",
    "https://images.unsplash.com/photo-1511920170033-f8396924c348",
]
IMG_PARAMS = "?auto=format&fit=crop&w=1200&q=70"

# Fictional but plausible HK owner names + short founder bios.
OWNERS = [
    ("Lam Chi-Keung", "A former barista champion who came home to Sheung Wan to roast his own beans."),
    ("Chan Mei-Ling", "Left a finance job to open a corner cafe where neighbours actually know your name."),
    ("Wong Ka-Ho", "Third-generation tea family who fell for single-origin espresso."),
    ("Cheung Siu-Fong", "Self-taught roaster obsessed with the perfect milk-tea-to-coffee crossover."),
    ("Ho Tsz-Wing", "Trained in Melbourne, came back to bring flat whites to Wellington Street."),
    ("Ng Wai-Man", "Quit architecture to design a cafe instead of buildings."),
    ("Lee Pui-Shan", "Runs the shop with her sister; their grandmother's stove still anchors the kitchen."),
    ("Tsang Ho-Yin", "Believes a HK$28 cup should taste like it costs HK$60."),
    ("Yeung Ka-Yan", "Opened during the pandemic to give the street a reason to slow down."),
    ("Fung Chun-Hei", "Cycles to the wholesale market every dawn for the day's pastries."),
    ("So Wing-Kei", "Ex-airline crew who now serves the regulars she used to fly past."),
    ("Kwok Tin-Lok", "Roasts on a 1970s machine he rebuilt himself."),
    ("Lau Sze-Man", "Turned her late father's hardware shop into a quiet coffee room."),
    ("Choi Ming-Fai", "Competition cupper who keeps a rotating guest-roaster shelf."),
    ("Tam Hoi-Ching", "Makes the oat milk in-house because the bought stuff never tasted right."),
    ("Poon Ka-Wai", "Hosts a Sunday cassette club between the espresso pulls."),
    ("Sit Yuen-Ying", "Keeps prices low so students can still afford a window seat."),
    ("Mok Chun-Yu", "Roaster-owner who labels every bag with the farm and the picker."),
    ("Hui Lok-Yi", "Brought slow-bar pour-over to a Tuen Mun side street."),
    ("Ngai Tsz-Ho", "Opens at 6am for the market porters before the tourists arrive."),
]

# Short neighbourhood "voices" woven into the listing description.
LOCAL_VOICES = [
    "Regulars call it the friendliest counter on the block.",
    "Neighbours say the cortado here ruined every other cup for them.",
    "Office workers queue out the door by 9am — and happily.",
    "Locals swear by the weekend cardamom bun.",
    "The corner table has hosted more first dates than anyone can count.",
    "Students treat it as a second living room.",
    "Old-timers and newcomers share the communal bench without a word.",
    "People come for the coffee and stay for the playlist.",
    "The owner remembers your order after one visit.",
    "It's the kind of place the whole lane would miss if it closed.",
]

INVESTOR_NAMES = ["M. Cheng", "Harbourfront Capital", "K. Lai", "Lantau Ventures", "S. Wong"]
BID_MESSAGES = [
    "Committed to keeping the roastery local and the staff on.",
    "Strong neighbourhood brand — we'd preserve the name and recipes.",
    "Looking for a hands-off operator partnership; owner stays on.",
    "We back independent HK F&B; happy to discuss earn-out terms.",
    "Clean books and loyal footfall. Serious offer.",
]

SOURCE = [
    ("Halfway Coffee", "26號 Upper Lascar Row, Sheung Wan", 22.2846615, 114.1497724, 4.5, 1424),
    ("commaa ，coffee . art . architecture", "G/F, Shop 4C, 11 Po Yan St, Sheung Wan", 22.2852712, 114.1472911, 4.6, 151),
    ("Zombie Specialty Coffee", "Jordan, Kwun Chung St, 9-13號Shop 1", 22.3036691, 114.1686036, 4.6, 185),
    ("Dear Neighbour Coffee", "West Point保德街15號號地下", 22.2847521, 114.1362845, 4.6, 294),
    ("Zero One Coffee & Roastery", "UG/F, 83 Wellington St, Central", 22.2832731, 114.1544754, 4.5, 287),
    ("Milligram Coffee", "Shop A, G/F, 174-178 Wellington St, Central", 22.2845165, 114.153149, 4.4, 206),
    ("Rootdown", "Shop 16-19 G/F, Two Artlane, 1 Chung Ching St, Sai Ying Pun", 22.2872648, 114.1414093, 4.6, 122),
    ("E N", "Shop B on LG/F, Wah Shin House, 6-10 Shin Hing St, Central", 22.2840367, 114.1520628, 4.3, 283),
    ("Uncle Ben Coffee", "Shop 7 G/F Fu Lee Loy Mansion 9-27 King Wah Road Fortress Hill, North Point", 22.2883872, 114.1917118, 4.7, 269),
    ("BLTN Coffee", "27 Haven St, So Kon Po", 22.2776084, 114.1869775, 4.5, 132),
    ("n.o.t. Specialty Coffee (Hysan Place)", "9/F, 500 Hennessy Rd, Causeway Bay", 22.2798226, 114.1837972, 3.9, 531),
    ("ARTISTA PERFETTO (Causeway Bay)", "Shop 2, G/F, 3A Sharp St W, Causeway Bay", 22.2776703, 114.1802791, 4.6, 382),
    ("NATIONS COFFEE", "Unit B, 2/F, Hundred City Centre, 17 Amoy St, Wan Chai", 22.2755622, 114.1717682, 4.6, 166),
    ("ztoryhome", "Sai Ying Pun, Queen's Rd W, 118號G/F & 1/F", 22.2861917, 114.1459627, 4.8, 163),
    ("Cafe Leitz by INTERVAL", "12 Pak Sha Rd, Causeway Bay", 22.2789272, 114.184122, 4.7, 58),
    ("Knockbox Coffee Company", "23號 Hak Po St, Mong Kok", 22.3176204, 114.1725583, 4.3, 840),
    ("Barista Jam", "G/F, 97 Jervois St, Sheung Wan", 22.285622, 114.150544, 4.3, 488),
    ("Hogan Coffee", "21號 Irving St, Causeway Bay", 22.2788236, 114.186745, 4.4, 154),
    ("Hidden Coffee & Roaster (Tuen Mun)", "Tuen Mun, Castle Peak Rd - San Hui, 97號6號鋪", 22.3972798, 113.9771135, 4.5, 380),
    ("Alternative Cafe", "G/F, Breakthrough Centre, 191 Woosung St, Jordan", 22.3035275, 114.1700498, 4.5, 276),
]


def district_for(address: str, lat: float, lng: float) -> str:
    a = address.lower()
    keywords = [
        ("sheung wan", "centralWestern"), ("jervois", "centralWestern"),
        ("po yan", "centralWestern"), ("upper lascar", "centralWestern"),
        ("sai ying pun", "saiYingPun"), ("west point", "saiYingPun"),
        ("queen's rd w", "saiYingPun"), ("artlane", "saiYingPun"),
        ("wellington", "central"), ("shin hing", "central"), ("central", "central"),
        ("wan chai", "wanChai"), ("amoy", "wanChai"),
        ("causeway bay", "causewayBay"), ("hennessy", "causewayBay"),
        ("so kon po", "causewayBay"), ("haven st", "causewayBay"),
        ("pak sha", "causewayBay"), ("irving", "causewayBay"), ("sharp st", "causewayBay"),
        ("north point", "eastern"), ("fortress hill", "eastern"), ("king wah", "eastern"),
        ("mong kok", "mongKok"), ("hak po", "mongKok"),
        ("jordan", "yauMaTei"), ("kwun chung", "yauMaTei"), ("woosung", "yauMaTei"),
        ("tuen mun", "tuenMun"),
    ]
    for needle, district in keywords:
        if needle in a:
            return district
    return "yauTsimMong" if lat > 22.30 else "central"


def gallery_for(index: int) -> list[str]:
    start = (index * 3) % len(COFFEE_IMAGES)
    picks = [COFFEE_IMAGES[(start + k) % len(COFFEE_IMAGES)] for k in range(4)]
    return [img + IMG_PARAMS for img in picks]


def founding_year(index: int) -> int:
    return 2007 + (index * 5) % 16


def description_for(name, address, rating, reviews, owner_name, owner_bio, voice):
    area = address.split(",")[-1].strip() if "," in address else address
    return (
        f"{name} is an independent specialty coffee house in {area}, Hong Kong, "
        f"founded by {owner_name}. {owner_bio} "
        f"Rated {rating}\u2605 across {reviews:,} reviews, it has become a fixture of "
        f"the lane — small, stubborn, and full of regulars. \u201c{voice}\u201d "
        f"Now the team is opening the next chapter to the community that built it."
    )


def financial_intent(index: int, reviews: int):
    asking = 1_500_000 + (reviews * 1500)
    bucket = index % 3
    if bucket == 0:
        return "sale", {"sale": {"targetAmount": asking}}, asking
    if bucket == 1:
        return "revenueShareLoan", {
            "revenueShareLoan": {
                "targetAmount": 600_000 + reviews * 800,
                "totalInterestPercentage": 8,
                "totalRevenueCutPercentage": 5,
            }
        }, asking
    return "donation", {
        "donation": {"tiers": [
            {"name": "Regular", "minAmount": 100},
            {"name": "Patron", "minAmount": 500},
            {"name": "Founding Supporter", "minAmount": 2000},
        ]}
    }, asking


class API:
    def __init__(self, base: str):
        self.base = base.rstrip("/")

    def _req(self, method, path, body=None, token=None):
        url = f"{self.base}/{path}"
        data = json.dumps(body).encode() if body is not None else None
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        last = None
        for attempt in range(3):  # retry transient 5xx/422 races
            try:
                with urllib.request.urlopen(req, timeout=30) as resp:
                    raw = resp.read().decode()
                    return json.loads(raw) if raw else {}
            except urllib.error.HTTPError as e:
                detail = e.read().decode()
                last = RuntimeError(f"{method} {path} -> {e.code}: {detail}")
                if e.code in (422, 500, 502, 503):
                    time.sleep(0.5 * (attempt + 1))
                    continue
                raise last from None
        raise last

    def dev_login(self, subject, investor=None, name=None):
        body = {"subject": subject}
        if investor:
            body["investorStatus"] = investor
        if name:
            body["name"] = name
        return self._req("POST", "auth/dev", body)["sessionToken"]

    def set_profile(self, token, name, biography):
        self._req("PATCH", "me", {"name": name, "biography": biography}, token)

    def create_business(self, token, body):
        res = self._req("POST", "businesses", body, token)
        return res.get("id") or res.get("_id")

    def verify(self, token, bid):
        self._req("POST", f"businesses/{bid}/verify", {}, token)

    def submit_sale(self, token, bid, body):
        self._req("POST", f"businesses/{bid}/sale", body, token)

    def place_bid(self, token, bid, amount, message):
        self._req("POST", f"businesses/{bid}/sale/bids", {"amount": amount, "message": message}, token)

    def like(self, token, bid):
        try:
            self._req("POST", f"businesses/{bid}/like", {}, token)
        except RuntimeError:
            pass  # already liked / not allowed — best-effort social proof

    def view(self, token, bid):
        try:
            self._req("GET", f"businesses/{bid}", None, token)
        except RuntimeError:
            pass


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed rich cafe listings into LBI.")
    parser.add_argument("--base", default=DEFAULT_BASE)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--seed", type=int, default=7, help="RNG seed for deterministic content.")
    args = parser.parse_args()

    random.seed(args.seed)
    api = API(args.base)
    print(f"Seeding {len(SOURCE)} cafes -> {args.base}\n")

    # A small pool of "fan" accounts to generate likes/views, and verified
    # investor accounts to place bids (created once, reused).
    fans = []
    investors = []
    if not args.dry_run:
        for f in range(6):
            fans.append(api.dev_login(f"cafe-fan-{f+1:02d}"))
        for inv_name in INVESTOR_NAMES:
            slug = inv_name.lower().replace(" ", "-").replace(".", "")
            investors.append((inv_name, api.dev_login(f"cafe-inv-{slug}", investor="institutionalVerified", name=inv_name)))

    created = []
    for i, (name, address, lat, lng, rating, reviews) in enumerate(SOURCE):
        district = district_for(address, lat, lng)
        assert district in VALID_DISTRICTS, district
        owner_name, owner_bio = OWNERS[i % len(OWNERS)]
        voice = LOCAL_VOICES[i % len(LOCAL_VOICES)]
        intent_kind, intent, asking = financial_intent(i, reviews)
        body = {
            "name": name,
            "description": description_for(name, address, rating, reviews, owner_name, owner_bio, voice),
            "foundingYear": founding_year(i),
            "categories": ["cafe"],
            "district": district,
            "address": address,
            "latitude": lat,
            "longitude": lng,
            "galleryImageUrls": gallery_for(i),
            "financialIntent": intent,
        }

        if args.dry_run:
            print(f"[{i+1:02d}] {name} | {district} | {intent_kind} | owner={owner_name}")
            print(json.dumps(body, ensure_ascii=False))
            print()
            continue

        try:
            token = api.dev_login(f"cafe-owner-{i+1:02d}")
            api.set_profile(token, owner_name, owner_bio)
            bid_id = api.create_business(token, body)
            api.verify(token, bid_id)

            if intent_kind == "sale":
                api.submit_sale(token, bid_id, {
                    "askingPrice": asking,
                    "financials": {
                        "annualRevenue": 1_200_000 + reviews * 1000,
                        "annualProfit": 240_000 + reviews * 300,
                        "monthlyRent": 38_000 + (i % 5) * 4000,
                        "leaseYearsRemaining": 3 + (i % 4),
                        "staffCount": 3 + (i % 4),
                        "inventoryValue": 60_000 + reviews * 200,
                        "notes": "Established neighbourhood clientele; loyal regulars.",
                    },
                    "includes": ["Equipment", "Brand & goodwill", "Recipes", "Supplier relationships"],
                    "ownerWillingToStay": True,
                    "handoverMonths": 3 + (i % 6),
                })
                # Seed 1–2 commercial bids below asking.
                n_bids = 1 + (i % 2)
                chosen = random.sample(investors, k=min(n_bids, len(investors)))
                for b, (inv_name, inv_token) in enumerate(chosen):
                    amount = int(asking * (0.86 + 0.04 * b))
                    api.place_bid(inv_token, bid_id, amount, random.choice(BID_MESSAGES))

            # Social proof: a random subset of fans like + several views.
            likers = random.sample(fans, k=random.randint(2, len(fans)))
            for fan in likers:
                api.like(fan, bid_id)
            for fan in fans:
                for _ in range(random.randint(1, 4)):
                    api.view(fan, bid_id)

            created.append((name, bid_id, district, intent_kind, len(likers)))
            print(f"[{i+1:02d}] OK  {name}  ({district}, {intent_kind}, {len(likers)} likes)  id={bid_id}")
        except Exception as exc:  # noqa: BLE001
            print(f"[{i+1:02d}] FAIL {name}: {exc}", file=sys.stderr)

    if not args.dry_run:
        print(f"\nDone. Created {len(created)}/{len(SOURCE)} businesses with owners, "
              f"bids and social proof.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
