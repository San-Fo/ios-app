# Mock / placeholder inventory & backend asks

This file is the single source of truth for **what is real vs. fake** in the
client, and **what we still need from the backend**.

## How to tell real data from mock data at runtime

- **Master switch:** `APIConfiguration.live.useMockData`
  (`LBI/Sources/Networking/APIConfiguration.swift`).
  - `true`  → every repository is a `Mock*` class; **nothing hits the backend**.
  - `false` → every repository is a `Live*` class hitting `baseURL`.
- **Launch banner:** on start the app logs (Console.app, subsystem
  `dev.tuist.LBI`):
  - `🟠🟠🟠 MOCK MODE …` when mock data is on, or
  - `🟢 LIVE MODE — using backend at <url>` when real.
- **Per-call markers:** every fake/derived path calls `MockMarker.hit(...)`
  (`LBI/Sources/Networking/MockMarker.swift`) and logs once under category
  `mock`, tagged:
  - `MOCK` — in-memory fake, no backend behind it.
  - `PLACEHOLDER` — hard-coded stand-in awaiting a real field/endpoint.
  - `DERIVED` — computed on the client because the backend will never provide
    it (expected even on the real-data path).
  - `NO_BACKEND` — feature with no endpoint yet; the call is a no-op/echo.

**Acceptance check for "everything is real":** run with `useMockData = false`,
exercise the app, and confirm the `mock` log shows **no `MOCK` / `PLACEHOLDER` /
`NO_BACKEND` lines** (only `DERIVED` lines are acceptable). `MockMarker.firedSites`
can be asserted in a UI/integration test.

---

## 1. Still mock because the switch is off

`useMockData = true` today. Flipping it to `false` makes all of the following
real (they are already wired to endpoints):

| Area | Live repo | Endpoints |
|---|---|---|
| Auth | `LiveAuthService` | `POST /auth/apple`, `POST /auth/dev`, `POST /auth/logout`, `GET /me` |
| Profile | `LiveProfileRepository` | `GET/PATCH /me`, `PUT /me/categories`, `PUT /me/financial-intents`, `PUT/DELETE /me/saved/{id}` |
| Business | `LiveBusinessRepository` | `GET /businesses/recommended`, `GET /businesses/search`, `GET /businesses/{id}` |
| Sale | `LiveSaleRepository` | `GET /sales`, `GET /businesses/{id}/sale`, `POST .../bids`, `.../bids/{id}/accept`, `.../decline-commercial-bids`, `POST /businesses/{id}/sale` |
| Chat | `LiveDealChatRepository` | `GET /me/conversations`, `GET /conversations/{id}`, `GET/POST /conversations/{id}/messages` |
| Takeover | `LiveTakeoverRepository` | `GET/POST /businesses/{id}/takeover-groups`, `.../join`, `.../leave`, `.../pledge`, `.../submit-offer` |
| Verification | `LiveVerificationRepository` | `POST /me/verify`, `POST /businesses/{id}/verify` |
| Listing/Actions | `LiveListingRepository` | `POST /businesses`, `POST /businesses/{id}/sale`, `POST /businesses/{id}/actions` |

To go live: set `useMockData = false` and run the backend with `DEV_AUTH=1`
(use `POST /auth/dev` for a session without a real Apple token).

---

## 2. DERIVED on the client (expected even with real data)

The backend intentionally does not provide these; the client computes them.
These `DERIVED` markers will still fire on the real path — that's fine.

- **Business editorial** (`BusinessDTO.toDetail`): `tagline`/`storyHeadline` ←
  `description`; `founderName`/`founderStory` ← embedded `owner`;
  `whyItMatters` ← `description`; `communityMemories`/`shareRewards` are empty.
- **AI memo extras** (`SaleEvaluationDTO.toDomain`): `recommendedAction` mapped
  from `verdict`; `confidence` defaulted to 0.8 (backend provides neither).
- **Account role** (`UserProfileDTO`): derived from `investorStatus`.
- **Funding kinds / listing status**: derived from `financialIntent` + sale
  stage for the discovery chips/badges.

---

## 3. Backend gaps — outstanding tasks (DO NOT FORGET)

The app has UI/flows ready and waiting on these. Ordered by priority.

### In flight (app fully ready; just needs the server)
| # | Gap | Endpoint / change needed | App side |
|---|---|---|---|
| 1 | **Image upload** | multipart or pre-signed URL upload returning a hosted URL | Wired behind `ImageUploader` seam (`LiveImageUploader.upload`); currently emits base64 `data:` URLs. One-file swap. Used by business gallery + listing photos. |
| 2 | **Apple Sign-In verification** | `POST /auth/apple` must verify the Apple identity token server-side | Fully wired (`LiveAuthService.signInWithApple` sends the real token). |

### ✅ DONE — now wired to real endpoints
| # | Feature | Status |
|---|---|---|
| 3 | **Community memories** | ✅ LIVE. `LiveBusinessRepository.addMemory` → `POST /businesses/{id}/memories` (`{body}`, author server-set). Memories decoded from `BusinessDTO.memories` and shown on detail; `commentCount` in stats. |
| 4 | **Ask a question** | ✅ LIVE. `AskQuestionView` → `POST /businesses/{id}/questions` (`{question}`). Public Q&A; owner answers via `.../questions/{id}/answer`. |

### Medium — partly built, workaround in place
| # | Gap | Endpoint needed | App side |
|---|---|---|---|
| 5 | **Deal status lifecycle** | mark payment pending / completed / cancel | Deal-chat menu offers all three; `Live.dealUpdateStatus` is a silent no-op (re-fetches). |
| 6 | **Founder Q&A (takeover)** | ask/answer a founder question on a takeover | `Live.askFounder` is a local echo **and has no UI caller**. (Distinct from the business Q&A in #4, which is live.) |
| 7 | **Richer search filters** | `GET /businesses/search` should honor `district`, funding/availability, and **multiple** categories (today: only `q` + one `category`) | Filters applied client-side in `BusinessQuery.matches` as a workaround — only filters the returned page, not ideal for pagination. |

### Low / product decision
| # | Gap | Notes |
|---|---|---|
| 8 | **`joinTakeover` user intent** | No server representation; `UserIntent.joinTakeover.serverIntent` returns `nil`, so the selection is dropped on save. Decide whether to add it. |
| 9 | **Equity / partial-ownership action** | Actions API supports only `purchase` / `donation` / `revenueShareLoan`. "Partial Ownership" is recorded as a donation (round-tripped consistently). A real equity action would make it faithful. |
| 10 | **Tokenized marketplace (Web3)** | **STUB only — no server.** `TokenMarketplaceView`, gated to verified commercial investors. Needs: token issuance per business, order book / trade endpoints, wallet linkage, settlement. See section 6. |
| 11 | **Verification skip/override** | `Live.verifySkipOverride` falls back to `submit`. Confirm there is no "skip/override grant" endpoint; we treat skip as submit. |

KYB is wired correctly: after the listing flow creates the business
(`POST /businesses`), it immediately prompts `BusinessVerificationView`, which
calls `verifyBusiness(businessId:)` → `POST /businesses/{id}/verify`, locking the
listing to a verified KYB and granting the owner role. The generic verification
section no longer offers KYB.

---

## 4. What we still need from the backend (logistics)

1. **Dev instance details** to run end-to-end: required envs are
   `MONGODB_URI`, `DATABASE_NAME`, `APPLE_BUNDLE_ID`, `DEV_AUTH=1`. Please share
   a reachable host/port (or confirm `http://localhost:3000`).
2. **`bidderName`/owner availability**: confirm whether `bidderName` and the
   embedded `owner` are populated in practice (we fall back to generic labels).
3. **Group offer member count**: a group's materialized sale bid has
   `bidderGroupId` but no member count; the UI shows 0. Provide member count on
   the bid or via the group, if you want it shown.
4. **Current user id for chat attribution**: we tag messages "You" by comparing
   `senderUserId` to the local user id. Confirm `GET /me`'s `id` equals the
   `senderUserId`/`participantIds` values (it should — just confirming).
5. **Decisions on the gap items in section 3.**
6. **Confidence/recommendedAction on `aiEvaluation`**: optional — say if you'd
   rather provide them than have us derive.

---

## 5. UI placeholders (cosmetic, not data)

These are normal UI affordances, not fake data, and need no backend:

- `RemoteImage` loading placeholder.
- Text-field placeholders in listing/onboarding/forms.
- Listing photos are hosted via the `ImageUploader` seam (data URLs until the
  real upload endpoint lands — see gap #1).

---

## 6. Tokenized marketplace (STUB — no server)

`TokenMarketplaceView` is an **example stump** for a future Web3 feature: small/
medium businesses get tokenized and traded as on-chain shares. It is:

- **Gated** to verified commercial investors only (`profile.isInstitutionalInvestor`).
- **Entirely client-side sample data** — every site fires `MockMarker.hit(.mock, ...)`.
  No wallet, no chain, no orders are real.

To make it real, the backend/chain would need at minimum:
- Token issuance per business (supply, symbol, decimals, contract address).
- An order book + trade/match endpoints (or a DEX integration).
- Wallet linkage to the user account and on-chain settlement.
- Holdings/positions per user and price history.

This is a stub to demo the concept; do not treat any number in it as real.
