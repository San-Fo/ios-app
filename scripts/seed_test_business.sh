#!/usr/bin/env bash
# Seeds one fully-populated, verified test business on the live backend so the
# client can validate decoding against real data.
#
# Flow: dev-auth (owner) -> create business -> submit sale -> verify (KYB).
# Requires the backend to be reachable with DEV_AUTH enabled.
#
# Usage: scripts/seed_test_business.sh
set -euo pipefail

BASE="${BASE:-https://lbi.proxied.zone/api/v1}"
json() { python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("id") or d.get("_id") or "")'; }
tok()  { python3 -c 'import sys,json;print(json.load(sys.stdin)["sessionToken"])'; }

echo "== dev-auth owner =="
AUTH=$(curl -fsS -X POST "$BASE/auth/dev" -H "Content-Type: application/json" \
  -d '{"subject":"owner-leung","name":"Leung Po-Wah"}')
TOKEN=$(printf '%s' "$AUTH" | tok)
AUTHH=(-H "Authorization: Bearer $TOKEN")
echo "token ok"

echo "== create business =="
BIZ=$(curl -fsS -X POST "$BASE/businesses" -H "Content-Type: application/json" "${AUTHH[@]}" -d '{
  "name": "Leung'\''s Master Tailoring",
  "description": "Bespoke suits for Hong Kong'\''s boardrooms since 1979.",
  "foundingYear": 1979,
  "categories": ["services"],
  "district": "central",
  "address": "Central, Hong Kong Island",
  "latitude": 22.2816,
  "longitude": 114.1578,
  "financialIntent": { "sale": { "targetAmount": 2200000 } }
}')
BIZID=$(printf '%s' "$BIZ" | json)
echo "business id: $BIZID"

echo "== submit sale =="
curl -fsS -X POST "$BASE/businesses/$BIZID/sale" -H "Content-Type: application/json" "${AUTHH[@]}" -d '{
  "askingPrice": 2200000,
  "financials": {
    "annualRevenue": 2220000,
    "annualProfit": 540000,
    "monthlyRent": 48000,
    "leaseYearsRemaining": 4,
    "staffCount": 3,
    "inventoryValue": 180000,
    "notes": "Established Central clientele; one trained apprentice retained."
  },
  "includes": ["Client archive", "Brand & goodwill", "Equipment"],
  "ownerWillingToStay": true,
  "handoverMonths": 12
}' >/dev/null
echo "sale submitted"

echo "== verify (KYB) =="
curl -fsS -X POST "$BASE/businesses/$BIZID/verify" -H "Content-Type: application/json" "${AUTHH[@]}" -d '{
  "businessRegistrationReference": "BR-TEST-0001",
  "documentReference": "DOC-TEST-0001"
}' >/dev/null
echo "verified"

echo "== final business =="
curl -fsS "$BASE/businesses/$BIZID" "${AUTHH[@]}"
echo
