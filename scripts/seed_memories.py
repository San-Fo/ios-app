#!/usr/bin/env python3
"""Seed realistic community memories (and optional public Q&A) onto the cafe
listings created by seed_cafes.py, using the real backend endpoints.

Backend contract (per API.md / backend team):
  - Create:  POST /businesses/{id}/memories   body: { "body": "..." }   (no author)
             author is derived server-side from the session token.
  - Read:    GET /businesses/{id} -> "memories": [ { id, authorUserId,
             authorName, body, createdAt } ], listingStatistics.commentCount
  - Q&A:     POST /businesses/{id}/questions   body: { "question": "..." }
             POST /businesses/{id}/questions/{qid}/answer  body: { "answer": "..." }

Each memory is posted by a distinct logged-in "neighbour" account so authorName
is realistic and varied. createdAt is server-set to now (acceptable per product).

The script first probes whether the endpoints are live; if they still 404 (older
deploy) it exits without writing, so it is safe to run repeatedly.

Usage:
    python3 scripts/seed_memories.py [--base URL] [--with-qa] [--dry-run]
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

# Neighbour personas that post memories. (subject, display name)
NEIGHBOURS = [
    ("mem-neighbour-01", "Ah Ming"),
    ("mem-neighbour-02", "Carmen Lau"),
    ("mem-neighbour-03", "Jacky Ho"),
    ("mem-neighbour-04", "Priya Nair"),
    ("mem-neighbour-05", "Wong Siu-Ling"),
    ("mem-neighbour-06", "Daniel Tse"),
    ("mem-neighbour-07", "Mei Chan"),
    ("mem-neighbour-08", "Oliver Yip"),
    ("mem-neighbour-09", "Tina Kwok"),
    ("mem-neighbour-10", "Marco Leung"),
    ("mem-neighbour-11", "Sandy Fung"),
    ("mem-neighbour-12", " Raymond Ng".strip()),
]

# Pool of believable, varied memory texts (neighbourhood voice).
MEMORY_TEXTS = [
    "Been coming here every morning before work for two years. The flat white never misses.",
    "They remembered my order on the second visit. That never happens anymore.",
    "Took my mum here on her birthday and the staff made her feel like a regular.",
    "Best cardamom bun on the island, full stop. Get there early on weekends.",
    "Quiet corner table + good wifi = my unofficial office.",
    "The owner walked me through three single-origins until we found my favourite.",
    "Rainy afternoon, hot cortado, nowhere I'd rather be.",
    "My kids learned to like 'grown-up coffee' here. Dangerous place.",
    "Prices stayed fair even when everything else on the street went up.",
    "Came as a tourist, left as a regular for the rest of my trip.",
    "The Sunday playlist alone is worth the walk.",
    "Watched this place grow from a tiny window counter. So proud of them.",
    "If this shop ever closed the whole lane would feel emptier.",
    "Their oat milk is house-made and you can taste the difference.",
    "Friendliest baristas in the district, no contest.",
    "First date here three years ago — now we come every anniversary.",
    "The roast they pulled for me last week was unreal. Bought a bag on the spot.",
    "Small space, huge heart. This is what a neighbourhood cafe should be.",
]

QA_QUESTIONS = [
    "Do you offer decaf single-origin options?",
    "Are dogs allowed at the outdoor seats?",
    "What time do the fresh pastries usually run out?",
    "Do you sell your house roast beans by the bag?",
    "Is there oat or soy milk available?",
]
QA_ANSWERS = [
    "Yes! We keep a rotating decaf single-origin on the slow bar.",
    "Absolutely — well-behaved dogs are welcome at the street tables.",
    "Usually by 11am on weekdays, earlier on weekends — come early!",
    "We do, 200g and 1kg bags, roasted in-house every week.",
    "Both oat (house-made) and soy are always on hand.",
]


class API:
    def __init__(self, base: str):
        self.base = base.rstrip("/")

    def req(self, method, path, body=None, token=None):
        url = f"{self.base}/{path}"
        data = json.dumps(body).encode() if body is not None else None
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        r = urllib.request.Request(url, data=data, headers=headers, method=method)
        last = None
        for attempt in range(3):
            try:
                with urllib.request.urlopen(r, timeout=30) as resp:
                    raw = resp.read().decode()
                    return resp.status, (json.loads(raw) if raw else {})
            except urllib.error.HTTPError as e:
                detail = e.read().decode()
                if e.code in (500, 502, 503):
                    last = RuntimeError(f"{method} {path} -> {e.code}: {detail}")
                    time.sleep(0.5 * (attempt + 1))
                    continue
                return e.code, detail
        raise last

    def dev_login(self, subject, name=None):
        body = {"subject": subject}
        if name:
            body["name"] = name
        _, res = self.req("POST", "auth/dev", body)
        return res["sessionToken"]

    def list_cafes(self):
        _, res = self.req("GET", "businesses/search?q=coffee&limit=50")
        cafes = res if isinstance(res, list) else []
        # also catch cafes whose name lacks "coffee"
        _, res2 = self.req("GET", "businesses/search?q=cafe&limit=50")
        seen = {c.get("_id") or c.get("id") for c in cafes}
        for c in (res2 if isinstance(res2, list) else []):
            cid = c.get("_id") or c.get("id")
            if cid not in seen:
                cafes.append(c)
                seen.add(cid)
        return cafes


def endpoints_live(api: API, sample_id: str, token: str) -> bool:
    """Probe the memories endpoint; True only if it accepts the create."""
    status, _ = api.req("POST", f"businesses/{sample_id}/memories",
                        {"body": "endpoint probe"}, token)
    if status in (200, 201):
        return True
    print(f"  probe POST /memories -> {status} (endpoints not deployed yet)")
    return False


def main() -> int:
    p = argparse.ArgumentParser(description="Seed community memories onto cafes.")
    p.add_argument("--base", default=DEFAULT_BASE)
    p.add_argument("--with-qa", action="store_true", help="Also seed public Q&A.")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--seed", type=int, default=11)
    args = p.parse_args()

    random.seed(args.seed)
    api = API(args.base)

    cafes = api.list_cafes()
    if not cafes:
        print("No cafes found via search. Run seed_cafes.py first.", file=sys.stderr)
        return 1
    print(f"Found {len(cafes)} cafe listings.")

    # Log in the neighbour pool.
    neighbours = []
    for subject, name in NEIGHBOURS:
        neighbours.append((name, api.dev_login(subject, name=name)))

    # Log in the owner pool (cafe-owner-01..20) so Q&A can be answered by owners.
    owner_tokens = []
    if args.with_qa:
        for n in range(1, 21):
            owner_tokens.append(api.dev_login(f"cafe-owner-{n:02d}"))

    if args.dry_run:
        for c in cafes:
            n = random.randint(2, 5)
            print(f"[dry] {c['name'][:30]:32} -> {n} memories"
                  + (" + 1 Q&A" if args.with_qa else ""))
        return 0

    # Endpoint readiness probe on the first cafe with the first neighbour.
    first_id = cafes[0].get("_id") or cafes[0].get("id")
    if not endpoints_live(api, first_id, neighbours[0][1]):
        print("\nAborting: memories endpoint is not live on this instance yet.\n"
              "Deploy current main (or point --base at the updated instance) and re-run.",
              file=sys.stderr)
        return 2

    total_mem = 0
    for c in cafes:
        cid = c.get("_id") or c.get("id")
        name = c.get("name", "?")
        n = random.randint(2, 5)
        posters = random.sample(neighbours, k=min(n, len(neighbours)))
        texts = random.sample(MEMORY_TEXTS, k=min(n, len(MEMORY_TEXTS)))
        count = 0
        for (poster_name, token), text in zip(posters, texts):
            status, _ = api.req("POST", f"businesses/{cid}/memories", {"body": text}, token)
            if status in (200, 201):
                count += 1
            else:
                print(f"   memory failed on {name}: {status}", file=sys.stderr)
        total_mem += count

        qa_note = ""
        if args.with_qa:
            asker_name, asker_token = random.choice(neighbours)
            idx = random.randrange(len(QA_QUESTIONS))
            q = QA_QUESTIONS[idx]
            qs, qres = api.req("POST", f"businesses/{cid}/questions", {"question": q}, asker_token)
            if qs in (200, 201) and isinstance(qres, dict):
                qa_note = " +Q"
                # Answer as the owner. We don't know the owner subject from the
                # listing, so answer via the owner pool: log in each cafe-owner-NN
                # and let the one who owns this business answer. Best-effort.
                question_id = (qres.get("questions") or [{}])[-1].get("id")
                if question_id and owner_for(api, cid, owner_tokens):
                    ot = owner_for(api, cid, owner_tokens)
                    astatus, _ = api.req(
                        "POST",
                        f"businesses/{cid}/questions/{question_id}/answer",
                        {"answer": QA_ANSWERS[idx]}, ot)
                    if astatus in (200, 201):
                        qa_note = " +Q&A"
        print(f"[OK] {name[:30]:32} {count} memories{qa_note}")

    print(f"\nDone. Posted {total_mem} memories across {len(cafes)} cafes.")
    return 0


# Cache: businessId -> owner token (resolved lazily by trying the owner pool).
def owner_for(api: "API", business_id: str, owner_tokens: list[str]) -> str | None:
    """Return the session token of the cafe-owner-NN account that owns this
    business, by checking each owner's /me/businesses. Cached per business."""
    cache = owner_for.__dict__.setdefault("_cache", {})
    if business_id in cache:
        return cache[business_id]
    for token in owner_tokens:
        _, mine = api.req("GET", "me/businesses", None, token)
        ids = {(b.get("_id") or b.get("id")) for b in (mine if isinstance(mine, list) else [])}
        if business_id in ids:
            cache[business_id] = token
            return token
    cache[business_id] = None
    return None


if __name__ == "__main__":
    raise SystemExit(main())
