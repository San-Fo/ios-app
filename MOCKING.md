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

## 3. NO_BACKEND — features with no endpoint yet

These currently no-op / echo on the live path and need a decision or endpoint:

| Site | What it does now | Ask |
|---|---|---|
| `Live.askFounder` | returns a local echo | Add a founder-Q&A endpoint, or we drop the feature. |
| `Live.dealUpdateStatus` | re-fetches, ignores status | Add deal lifecycle status (negotiating / paymentPending / completed), or we keep it client-only. |
| `Live.acceptRetailPurchase` | throws `notFound` | Add a retail-purchase accept that opens a deal conversation, or confirm retail purchase is only a `purchase` Action with no chat. |
| `Live.verifyKYB.generic` | returns `pending` | KYB is per-business; we will trigger `POST /businesses/{id}/verify` from the owner's listing screen (wiring pending). |
| `Live.verifySkipOverride` | falls back to `submit` | Confirm there is no "skip/override grant" endpoint; we treat skip as submit. |

---

## 4. What we still need from the backend

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
5. **Decisions on the NO_BACKEND items in section 3.**
6. **Confidence/recommendedAction on `aiEvaluation`**: optional — say if you'd
   rather provide them than have us derive.

---

## 5. UI placeholders (cosmetic, not data)

These are normal UI affordances, not fake data, and need no backend:

- `RemoteImage` loading placeholder.
- Text-field placeholders in listing/onboarding/forms.
- `ListingFlowView.photoPlaceholder` (photo upload is not yet wired — see the
  `TODO(API): photo upload` in `LiveListingRepository`).
