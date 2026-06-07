#!/usr/bin/env python3
"""Seed sample data for EVERY finance / selling option a business owner can
create, and simulate PARTIAL completion of each goal. Pushes to the real server
via the public API. Demo-data tool only; does not touch app code.

What the server actually tracks (so "partial completion" = these real states):
  - SALE lifecycle stage: commercialBidding -> (accept) -> accepted, or
    (decline) -> openToRetail. Bids accumulate against the asking price.
  - REVENUE-SHARE LOAN: contribution `actions` from verified investors
    accumulate toward the target (server stores each action).
  - DONATION: donation `actions` from supporters accumulate toward the goal.
  - GROUP TAKEOVER: a takeover group gathers members + pledges vs a target.

Scenarios created (each a distinct business so every state is visible):
  1. sale_fresh          - on the market, 0 bids (0% interest)
  2. sale_bidding        - several bids, highest ~80% of ask (partial)
  3. sale_hot            - many bids, highest ~98% of ask (almost there)
  4. sale_accepted       - a bid accepted -> deal conversation opened (done-ish)
  5. loan_early          - revenue-share loan ~20% funded
  6. loan_mid            - revenue-share loan ~65% funded
  7. donation_early      - donation campaign ~15% funded
  8. donation_almost     - donation campaign ~90% funded
  9. retail_outright     - declined to public; some outright-purchase interest
 10. takeover_forming    - group takeover, ~40% of target members/pledge
 11. takeover_near       - group takeover, ~85% of target members/pledge

Usage:
    python3 scripts/seed_options.py [--base URL] [--dry-run]
"""
from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request

DEFAULT_BASE = "https://lbi.proxied.zone/api/v1"

IMG = "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=70"
CAFE_IMG = "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=1200&q=70"

INVESTORS = ["Harbourfront Capital", "K. Lai", "Lantau Ventures", "S. Wong", "Victoria Peak Partners", "Kowloon Growth"]
SUPPORTERS = [("opt-sup-01", "Ah Ming"), ("opt-sup-02", "Carmen Lau"), ("opt-sup-03", "Jacky Ho"),
              ("opt-sup-04", "Priya Nair"), ("opt-sup-05", "Mei Chan"), ("opt-sup-06", "Daniel Tse"),
              ("opt-sup-07", "Tina Kwok"), ("opt-sup-08", "Marco Leung")]


class API:
    def __init__(self, base):
        self.base = base.rstrip("/")

    def req(self, method, path, body=None, token=None, retries=5):
        url = f"{self.base}/{path}"
        data = json.dumps(body).encode() if body is not None else None
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        last = None
        for attempt in range(retries):
            r = urllib.request.Request(url, data=data, headers=headers, method=method)
            try:
                with urllib.request.urlopen(r, timeout=30) as resp:
                    raw = resp.read().decode()
                    return resp.status, (json.loads(raw) if raw else {})
            except urllib.error.HTTPError as e:
                detail = e.read().decode()
                last = RuntimeError(f"{method} {path} -> {e.code}: {detail}")
                # 422 here is a known transient write race on this backend.
                if e.code in (422, 500, 502, 503):
                    time.sleep(0.5 * (attempt + 1))
                    continue
                return e.code, detail
        raise last

    def login(self, subject, investor=None, vstate=None, name=None):
        body = {"subject": subject}
        if investor:
            body["investorStatus"] = investor
        if vstate:
            body["verificationState"] = vstate
        if name:
            body["name"] = name
        return self.req("POST", "auth/dev", body)[1]["sessionToken"]

    def create_business(self, token, name, cat, intent, founded, owner, bio, img):
        body = {
            "name": name,
            "description": f"{bio} Founded in {founded} by {owner}.",
            "foundingYear": founded,
            "categories": [cat],
            "district": "central",
            "address": "Central, Hong Kong",
            "latitude": 22.2820, "longitude": 114.1588,
            "galleryImageUrls": [img],
            "financialIntent": intent,
        }
        bid = self.req("POST", "businesses", body, token)[1]
        bid_id = bid.get("id") or bid.get("_id") if isinstance(bid, dict) else None
        self.req("POST", f"businesses/{bid_id}/verify", {}, token)
        self.set_profile(token, owner, bio)
        return bid_id

    def set_profile(self, token, name, bio):
        self.req("PATCH", "me", {"name": name, "biography": bio}, token)

    def submit_sale(self, token, bid_id, asking):
        self.req("POST", f"businesses/{bid_id}/sale", {
            "askingPrice": asking,
            "financials": {"annualRevenue": int(asking * 0.8), "annualProfit": int(asking * 0.2),
                           "monthlyRent": 42000, "leaseYearsRemaining": 4, "staffCount": 5,
                           "inventoryValue": 90000, "notes": "Loyal regulars; established brand."},
            "includes": ["Equipment", "Brand & goodwill", "Recipes"],
            "ownerWillingToStay": True, "handoverMonths": 6,
        }, token)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--base", default=DEFAULT_BASE)
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()
    api = API(args.base)

    scenarios = [
        "sale_fresh", "sale_bidding", "sale_hot", "sale_accepted",
        "loan_early", "loan_mid", "donation_early", "donation_almost",
        "retail_outright", "takeover_forming", "takeover_near",
    ]
    print(f"Seeding {len(scenarios)} option scenarios -> {args.base}\n")
    if args.dry_run:
        for s in scenarios:
            print("  -", s)
        return 0

    # Shared actor pools.
    investors = [(nm, api.login(f"opt-inv-{nm.lower().replace(' ','-').replace('.','')}",
                                investor="institutionalVerified", vstate="verified", name=nm))
                 for nm in INVESTORS]
    supporters = [(nm, api.login(subj, name=nm)) for subj, nm in SUPPORTERS]

    results = []

    def log(name, detail):
        results.append((name, detail))
        print(f"[OK] {name:22} {detail}")

    # --- SALE scenarios ---
    def make_sale(name, owner, bio, asking):
        bid_id = api.create_business(api.login(f"opt-owner-{name}"), f"[{name}] " + bio.split('.')[0][:24],
                                     "restaurant", {"sale": {"targetAmount": asking}}, 1998, owner, bio, IMG)
        # re-login as owner for sale submit (same subject)
        otok = api.login(f"opt-owner-{name}")
        api.submit_sale(otok, bid_id, asking)
        return bid_id, otok

    def place_bids(bid_id, asking, fractions):
        for frac, (inv_name, inv_tok) in zip(fractions, investors):
            api.req("POST", f"businesses/{bid_id}/sale/bids",
                    {"amount": int(asking * frac), "message": f"Offer at {int(frac*100)}% of guide."}, inv_tok)

    asking = 3_000_000
    # 1. fresh, no bids
    bid_id, _ = make_sale("sale-fresh", "Lo Kin-Wah", "On the market, awaiting first offers.", asking)
    log("sale_fresh", "commercialBidding, 0 bids (0%)")

    # 2. bidding, partial (~80%)
    bid_id, _ = make_sale("sale-bidding", "Chan Mei-Ling", "Active commercial bidding underway.", asking)
    place_bids(bid_id, asking, [0.70, 0.76, 0.80])
    log("sale_bidding", "3 bids, highest ~80% of ask")

    # 3. hot, near ask (~98%)
    bid_id, _ = make_sale("sale-hot", "Wong Ka-Ho", "Heavy interest, near asking price.", asking)
    place_bids(bid_id, asking, [0.85, 0.92, 0.96, 0.98])
    log("sale_hot", "4 bids, highest ~98% of ask")

    # 4. accepted -> deal conversation
    bid_id, otok = make_sale("sale-accepted", "Tsui Mei-Fong", "A bid was accepted; deal in progress.", asking)
    place_bids(bid_id, asking, [0.90, 0.95])
    time.sleep(1)
    _, sale = api.req("GET", f"businesses/{bid_id}/sale", None, otok)
    bids = (sale.get("sale") or {}).get("bids") or []
    if bids:
        top = max(bids, key=lambda b: b["amount"])
        api.req("POST", f"businesses/{bid_id}/sale/bids/{top['id']}/accept", None, otok)
    log("sale_accepted", "top bid accepted -> deal opened")

    # --- LOAN scenarios (verified investors contribute via actions) ---
    def make_loan(name, owner, bio, target):
        otok = api.login(f"opt-owner-{name}")
        return api.create_business(otok, f"[{name}] " + bio.split('.')[0][:24], "cafe",
                                   {"revenueShareLoan": {"targetAmount": target,
                                    "totalInterestPercentage": 8, "totalRevenueCutPercentage": 5}},
                                   2016, owner, bio, CAFE_IMG)

    def contribute_loan(bid_id, amounts):
        for amt, (inv_name, inv_tok) in zip(amounts, investors):
            api.req("POST", f"businesses/{bid_id}/actions", {"kind": "revenueShareLoan", "amount": amt}, inv_tok)

    target = 800_000
    bid_id = make_loan("loan-early", "Ho Tsz-Wing", "Revenue-share raise, early days.", target)
    contribute_loan(bid_id, [90_000, 70_000])  # ~20%
    log("loan_early", "~20% of HK$800k via investor actions")

    bid_id = make_loan("loan-mid", "Lin Ka-Yiu", "Revenue-share raise, gaining momentum.", target)
    contribute_loan(bid_id, [150_000, 180_000, 190_000])  # ~65%
    log("loan_mid", "~65% of HK$800k via investor actions")

    # --- DONATION scenarios (supporters donate via actions) ---
    def make_donation(name, owner, bio):
        otok = api.login(f"opt-owner-{name}")
        return api.create_business(otok, f"[{name}] " + bio.split('.')[0][:24], "artsAndCrafts",
                                   {"donation": {"tiers": [{"name": "Friend", "minAmount": 100},
                                    {"name": "Patron", "minAmount": 500},
                                    {"name": "Guardian", "minAmount": 2500}]}},
                                   1969, owner, bio, IMG)

    def donate(bid_id, amounts):
        for amt, (sup_name, sup_tok) in zip(amounts, supporters):
            tier = "Guardian" if amt >= 2500 else "Patron" if amt >= 500 else "Friend"
            api.req("POST", f"businesses/{bid_id}/actions",
                    {"kind": "donation", "amount": amt, "tier": tier}, sup_tok)

    bid_id = make_donation("don-early", "Master Kwan", "Community campaign, just launched.")
    donate(bid_id, [200, 500, 750])  # early
    log("donation_early", "~15% goal, 3 supporters")

    bid_id = make_donation("don-almost", "Auntie Sin", "Community campaign, almost funded.")
    donate(bid_id, [2500, 2500, 1500, 1000, 900, 800, 700])  # near goal
    log("donation_almost", "~90% goal, 7 supporters")

    # --- RETAIL OUTRIGHT (declined to public) ---
    bid_id, otok = make_sale("retail-outright", "Wong Tai-Sang", "Declined commercial bids; open to the public.", 2_500_000)
    api.req("POST", f"businesses/{bid_id}/sale/decline-commercial-bids", {
        "retailAskingPrice": 2_300_000, "allowOutrightPurchase": True,
        "allowGroupTakeover": False, "ownerNote": "Prefer a single local owner."}, otok)
    log("retail_outright", "openToRetail, outright purchase only")

    # --- GROUP TAKEOVER scenarios ---
    def make_takeover(name, owner, bio, allow_group=True):
        otok = api.login(f"opt-owner-{name}")
        bid_id = api.create_business(otok, f"[{name}] " + bio.split('.')[0][:24], "restaurant",
                                     {"sale": {"targetAmount": 2_800_000}}, 1979, owner, bio, IMG)
        api.submit_sale(otok, bid_id, 2_800_000)
        api.req("POST", f"businesses/{bid_id}/sale/decline-commercial-bids", {
            "retailAskingPrice": 2_600_000, "allowOutrightPurchase": True,
            "allowGroupTakeover": True, "ownerNote": "Open to a neighbourhood group."}, otok)
        return bid_id

    def build_group(bid_id, label, joiner_count, pledge):
        starter_name, starter = supporters[0]
        _, g = api.req("POST", f"businesses/{bid_id}/takeover-groups",
                       {"name": label, "pledgeAmount": pledge}, starter)
        gid = g.get("id") or g.get("_id") if isinstance(g, dict) else None
        for nm, tok in supporters[1:joiner_count]:
            api.req("POST", f"takeover-groups/{gid}/join", {"pledgeAmount": pledge}, tok)
        return gid

    bid_id = make_takeover("tk-forming", "Poon Lai-Han", "Community group forming to take over.")
    build_group(bid_id, "Friends (forming)", 3, 30_000)   # ~3 of 8
    log("takeover_forming", "group ~40% of target members")

    bid_id = make_takeover("tk-near", "Sit Yuen-Ying", "Community group nearly complete.")
    build_group(bid_id, "Friends (almost there)", 7, 45_000)  # ~7 of 8
    log("takeover_near", "group ~85% of target members")

    print(f"\nDone. Created {len(results)} option scenarios with partial progress.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
