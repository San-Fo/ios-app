# Hong Kong Local Business Preservation Backend Blueprint

## 1. Recommended Backend Architecture

Recommended stack: Python FastAPI, PostgreSQL, SQLAlchemy 2.0, Alembic, Pydantic v2, JWT auth, Docker Compose.

Rationale:
- FastAPI gives first-class OpenAPI docs, strong request/response validation, and fast backend iteration for an iOS client.
- PostgreSQL is a good fit for relational deal workflows, audit logs, role memberships, search filters, and financial records.
- SQLAlchemy plus Alembic keeps the schema explicit and migration-friendly.
- A modular service architecture keeps admin, deal-room, investment, and recommendation logic isolated enough for later compliance hardening.

High-level components:
- API layer: FastAPI routers grouped by domain.
- Application services: business rules, state transitions, permission checks, recommendation scoring.
- Persistence layer: SQLAlchemy models, repositories, transactions.
- Security layer: JWT access/refresh tokens, password hashing, RBAC, rate limiting.
- Background jobs: future queue for notifications, document scans, recommendation refreshes.
- Storage: local/S3-compatible object storage for documents and business images.
- Observability: structured JSON logging, request IDs, audit logs.

Primary modules:
- `auth`
- `users`
- `businesses`
- `stories`
- `financials`
- `financing`
- `investments`
- `recommendations`
- `takeover_groups`
- `qa`
- `admin`
- `deal_rooms`
- `documents`
- `audit`

## 2. Repo Structure

```text
backend/
  app/
    main.py
    core/
      config.py
      database.py
      security.py
      logging.py
      rate_limit.py
      permissions.py
    models/
      user.py
      business.py
      financing.py
      investment.py
      takeover_group.py
      deal_room.py
      document.py
      audit.py
    schemas/
      auth.py
      user.py
      business.py
      financing.py
      investment.py
      takeover_group.py
      deal_room.py
      admin.py
    routers/
      auth.py
      users.py
      businesses.py
      investments.py
      recommendations.py
      takeover_groups.py
      qa.py
      admin.py
      deal_rooms.py
    services/
      auth_service.py
      business_service.py
      investment_service.py
      recommendation_service.py
      takeover_group_service.py
      deal_room_service.py
      audit_service.py
    repositories/
      base.py
      users.py
      businesses.py
      investments.py
    migrations/
      env.py
      versions/
    seeds/
      seed_dev.py
    tests/
      conftest.py
      test_auth.py
      test_businesses.py
      test_investments.py
  docker/
    Dockerfile
  docker-compose.yml
  alembic.ini
  pyproject.toml
  .env.example
  README.md
```

## 3. PostgreSQL Schema

Enums:

```sql
CREATE TYPE user_role AS ENUM ('retail_user', 'business_owner', 'group_organizer', 'admin');
CREATE TYPE financing_type AS ENUM ('support_only', 'revenue_share', 'partial_ownership', 'full_acquisition', 'loan', 'collective_takeover');
CREATE TYPE deal_stage AS ENUM ('draft', 'submitted', 'approved', 'listed', 'funding_open', 'negotiation', 'due_diligence', 'offer_submitted', 'funded', 'acquired', 'closed');
CREATE TYPE investment_status AS ENUM ('intent', 'pending_review', 'confirmed', 'cancelled', 'refunded');
CREATE TYPE group_member_role AS ENUM ('investor', 'operator', 'accountant', 'marketing', 'legal', 'supporter');
CREATE TYPE admin_review_status AS ENUM ('pending', 'approved', 'rejected', 'changes_requested');
```

Core tables:

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role user_role NOT NULL DEFAULT 'retail_user',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  email_verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE user_profiles (
  id UUID PRIMARY KEY,
  user_id UUID UNIQUE NOT NULL REFERENCES users(id),
  display_name TEXT NOT NULL,
  phone TEXT,
  bio TEXT,
  preferred_districts TEXT[] NOT NULL DEFAULT '{}',
  investment_min_amount NUMERIC(14,2),
  investment_max_amount NUMERIC(14,2),
  preferred_financing_types financing_type[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE user_interests (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  category TEXT NOT NULL,
  weight INT NOT NULL DEFAULT 1,
  UNIQUE (user_id, category)
);

CREATE TABLE businesses (
  id UUID PRIMARY KEY,
  owner_user_id UUID REFERENCES users(id),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  category TEXT NOT NULL,
  district TEXT NOT NULL,
  address TEXT,
  latitude NUMERIC(9,6),
  longitude NUMERIC(9,6),
  short_description TEXT NOT NULL,
  status deal_stage NOT NULL DEFAULT 'draft',
  financing_types financing_type[] NOT NULL DEFAULT '{}',
  urgency_score INT NOT NULL DEFAULT 0,
  popularity_score INT NOT NULL DEFAULT 0,
  owner_retirement_risk BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE business_stories (
  id UUID PRIMARY KEY,
  business_id UUID UNIQUE NOT NULL REFERENCES businesses(id),
  founder_story TEXT,
  family_legacy TEXT,
  cultural_relevance TEXT,
  neighbourhood_importance TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE business_financial_snapshots (
  id UUID PRIMARY KEY,
  business_id UUID UNIQUE NOT NULL REFERENCES businesses(id),
  monthly_revenue_min NUMERIC(14,2),
  monthly_revenue_max NUMERIC(14,2),
  monthly_profit_min NUMERIC(14,2),
  monthly_profit_max NUMERIC(14,2),
  monthly_rent NUMERIC(14,2),
  employee_count INT,
  assets_summary TEXT,
  debts_summary TEXT,
  years_operating INT,
  funding_needed NUMERIC(14,2),
  asking_price NUMERIC(14,2),
  currency CHAR(3) NOT NULL DEFAULT 'HKD',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE business_images (
  id UUID PRIMARY KEY,
  business_id UUID NOT NULL REFERENCES businesses(id),
  url TEXT NOT NULL,
  alt_text TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Financing, investment, and community:

```sql
CREATE TABLE financing_proposals (
  id UUID PRIMARY KEY,
  business_id UUID NOT NULL REFERENCES businesses(id),
  financing_type financing_type NOT NULL,
  target_amount NUMERIC(14,2),
  minimum_investment_amount NUMERIC(14,2),
  current_amount_raised NUMERIC(14,2) NOT NULL DEFAULT 0,
  deal_stage deal_stage NOT NULL DEFAULT 'draft',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE revenue_share_terms (
  id UUID PRIMARY KEY,
  proposal_id UUID UNIQUE NOT NULL REFERENCES financing_proposals(id),
  revenue_share_percent NUMERIC(5,2) NOT NULL,
  repayment_cap_multiplier NUMERIC(5,2),
  expected_term_months INT
);

CREATE TABLE ownership_terms (
  id UUID PRIMARY KEY,
  proposal_id UUID UNIQUE NOT NULL REFERENCES financing_proposals(id),
  equity_percent_offered NUMERIC(5,2) NOT NULL,
  investor_rights_summary TEXT
);

CREATE TABLE acquisition_terms (
  id UUID PRIMARY KEY,
  proposal_id UUID UNIQUE NOT NULL REFERENCES financing_proposals(id),
  asking_price NUMERIC(14,2) NOT NULL,
  includes_assets BOOLEAN NOT NULL DEFAULT TRUE,
  handover_support_months INT
);

CREATE TABLE loan_terms (
  id UUID PRIMARY KEY,
  proposal_id UUID UNIQUE NOT NULL REFERENCES financing_proposals(id),
  principal_amount NUMERIC(14,2) NOT NULL,
  interest_rate_percent NUMERIC(5,2),
  term_months INT
);

CREATE TABLE investments (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  business_id UUID NOT NULL REFERENCES businesses(id),
  proposal_id UUID REFERENCES financing_proposals(id),
  financing_type financing_type NOT NULL,
  amount NUMERIC(14,2) NOT NULL,
  status investment_status NOT NULL DEFAULT 'intent',
  confirmed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE investment_intents (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  business_id UUID NOT NULL REFERENCES businesses(id),
  financing_type financing_type NOT NULL,
  amount_min NUMERIC(14,2),
  amount_max NUMERIC(14,2),
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE support_follows (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  business_id UUID NOT NULL REFERENCES businesses(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, business_id)
);

CREATE TABLE community_memories (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  business_id UUID NOT NULL REFERENCES businesses(id),
  body TEXT NOT NULL,
  is_published BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Takeover groups, Q&A, deal rooms, documents, admin, audit:

```sql
CREATE TABLE takeover_groups (
  id UUID PRIMARY KEY,
  business_id UUID NOT NULL REFERENCES businesses(id),
  organizer_user_id UUID NOT NULL REFERENCES users(id),
  name TEXT NOT NULL,
  goal_summary TEXT,
  target_offer_amount NUMERIC(14,2),
  submitted_offer_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE takeover_group_members (
  id UUID PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES takeover_groups(id),
  user_id UUID NOT NULL REFERENCES users(id),
  role group_member_role NOT NULL DEFAULT 'supporter',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (group_id, user_id)
);

CREATE TABLE takeover_group_messages (
  id UUID PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES takeover_groups(id),
  user_id UUID NOT NULL REFERENCES users(id),
  body TEXT NOT NULL,
  is_moderated BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE business_questions (
  id UUID PRIMARY KEY,
  business_id UUID NOT NULL REFERENCES businesses(id),
  user_id UUID NOT NULL REFERENCES users(id),
  question TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE business_answers (
  id UUID PRIMARY KEY,
  question_id UUID UNIQUE NOT NULL REFERENCES business_questions(id),
  answered_by_user_id UUID NOT NULL REFERENCES users(id),
  answer TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE deal_rooms (
  id UUID PRIMARY KEY,
  business_id UUID NOT NULL REFERENCES businesses(id),
  name TEXT NOT NULL,
  created_by_user_id UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE deal_room_members (
  id UUID PRIMARY KEY,
  deal_room_id UUID NOT NULL REFERENCES deal_rooms(id),
  user_id UUID NOT NULL REFERENCES users(id),
  role TEXT NOT NULL DEFAULT 'viewer',
  added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (deal_room_id, user_id)
);

CREATE TABLE documents (
  id UUID PRIMARY KEY,
  deal_room_id UUID REFERENCES deal_rooms(id),
  business_id UUID REFERENCES businesses(id),
  uploaded_by_user_id UUID NOT NULL REFERENCES users(id),
  file_name TEXT NOT NULL,
  content_type TEXT NOT NULL,
  storage_key TEXT NOT NULL,
  size_bytes BIGINT NOT NULL,
  checksum_sha256 TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE admin_reviews (
  id UUID PRIMARY KEY,
  business_id UUID NOT NULL REFERENCES businesses(id),
  reviewer_user_id UUID NOT NULL REFERENCES users(id),
  status admin_review_status NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE audit_logs (
  id UUID PRIMARY KEY,
  actor_user_id UUID REFERENCES users(id),
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  ip_address INET,
  user_agent TEXT,
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Important indexes:

```sql
CREATE INDEX idx_businesses_search ON businesses (status, district, category);
CREATE INDEX idx_businesses_financing_types ON businesses USING GIN (financing_types);
CREATE INDEX idx_investments_user ON investments (user_id, created_at DESC);
CREATE INDEX idx_investments_business ON investments (business_id, created_at DESC);
CREATE INDEX idx_audit_logs_entity ON audit_logs (entity_type, entity_id, created_at DESC);
CREATE INDEX idx_documents_deal_room ON documents (deal_room_id, created_at DESC);
```

## 4. API Endpoint List

Auth:
- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh`
- `POST /auth/logout`
- `GET /auth/me`

Users:
- `GET /users/me`
- `PATCH /users/me/profile`
- `PUT /users/me/interests`
- `GET /users/me/saved-businesses`
- `GET /users/me/groups`

Businesses:
- `POST /businesses`
- `GET /businesses`
- `GET /businesses/{business_id}`
- `PATCH /businesses/{business_id}`
- `POST /businesses/{business_id}/submit`
- `POST /businesses/{business_id}/images`
- `GET /businesses/{business_id}/story`
- `PUT /businesses/{business_id}/story`
- `GET /businesses/{business_id}/financial-snapshot`
- `PUT /businesses/{business_id}/financial-snapshot`
- `POST /businesses/{business_id}/follow`
- `DELETE /businesses/{business_id}/follow`
- `POST /businesses/{business_id}/memories`
- `GET /businesses/{business_id}/memories`

Financing:
- `POST /businesses/{business_id}/financing-proposals`
- `GET /businesses/{business_id}/financing-proposals`
- `PATCH /financing-proposals/{proposal_id}`
- `PUT /financing-proposals/{proposal_id}/revenue-share-terms`
- `PUT /financing-proposals/{proposal_id}/ownership-terms`
- `PUT /financing-proposals/{proposal_id}/acquisition-terms`
- `PUT /financing-proposals/{proposal_id}/loan-terms`

Investments:
- `POST /investments`
- `GET /investments/me`
- `GET /businesses/{business_id}/investments`
- `POST /investment-intents`
- `GET /investment-intents/me`
- `POST /investments/{investment_id}/confirm`
- `POST /investments/{investment_id}/cancel`

Recommendations:
- `GET /recommendations/businesses`

Takeover groups:
- `POST /businesses/{business_id}/takeover-groups`
- `GET /businesses/{business_id}/takeover-groups`
- `GET /takeover-groups/{group_id}`
- `POST /takeover-groups/{group_id}/join`
- `POST /takeover-groups/{group_id}/leave`
- `PATCH /takeover-groups/{group_id}/members/{member_id}`
- `POST /takeover-groups/{group_id}/messages`
- `GET /takeover-groups/{group_id}/messages`
- `POST /takeover-groups/{group_id}/submit-offer`

Business Q&A:
- `POST /businesses/{business_id}/questions`
- `GET /businesses/{business_id}/questions`
- `POST /questions/{question_id}/answer`

Deal rooms:
- `POST /businesses/{business_id}/deal-rooms`
- `GET /deal-rooms/{deal_room_id}`
- `POST /deal-rooms/{deal_room_id}/members`
- `DELETE /deal-rooms/{deal_room_id}/members/{member_id}`
- `POST /deal-rooms/{deal_room_id}/documents`
- `GET /deal-rooms/{deal_room_id}/documents`
- `GET /documents/{document_id}/download`

Admin:
- `GET /admin/businesses/submitted`
- `POST /admin/businesses/{business_id}/approve`
- `POST /admin/businesses/{business_id}/reject`
- `POST /admin/businesses/{business_id}/publish`
- `PATCH /admin/businesses/{business_id}/deal-stage`
- `GET /admin/investments`
- `GET /admin/deal-rooms`
- `POST /admin/takeover-group-messages/{message_id}/moderate`
- `GET /admin/audit-logs`

## 5. DTOs / Request-Response Models

Representative request models:

```python
class RegisterRequest(BaseModel):
    email: EmailStr
    password: SecretStr = Field(min_length=10, max_length=128)
    role: UserRole = UserRole.retail_user
    display_name: str = Field(min_length=1, max_length=100)

class LoginRequest(BaseModel):
    email: EmailStr
    password: SecretStr

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"
    expires_in: int

class BusinessCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    category: str = Field(min_length=1, max_length=80)
    district: str = Field(min_length=1, max_length=80)
    address: str | None = None
    short_description: str = Field(min_length=20, max_length=500)
    financing_types: list[FinancingType] = []

class BusinessSearchQuery(BaseModel):
    q: str | None = None
    district: str | None = None
    category: str | None = None
    financing_type: FinancingType | None = None
    min_funding_needed: Decimal | None = None
    max_funding_needed: Decimal | None = None
    limit: int = Field(default=20, le=100)
    offset: int = Field(default=0, ge=0)

class FinancialSnapshotUpsertRequest(BaseModel):
    monthly_revenue_min: Decimal | None = None
    monthly_revenue_max: Decimal | None = None
    monthly_profit_min: Decimal | None = None
    monthly_profit_max: Decimal | None = None
    monthly_rent: Decimal | None = None
    employee_count: int | None = Field(default=None, ge=0)
    assets_summary: str | None = None
    debts_summary: str | None = None
    years_operating: int | None = Field(default=None, ge=0)
    funding_needed: Decimal | None = None
    asking_price: Decimal | None = None

class FinancingProposalCreateRequest(BaseModel):
    financing_type: FinancingType
    target_amount: Decimal | None = None
    minimum_investment_amount: Decimal | None = None

class InvestmentCreateRequest(BaseModel):
    business_id: UUID
    proposal_id: UUID | None = None
    financing_type: FinancingType
    amount: Decimal = Field(gt=0)

class TakeoverGroupCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    goal_summary: str | None = Field(default=None, max_length=1000)
    target_offer_amount: Decimal | None = None

class DealRoomMemberAddRequest(BaseModel):
    user_id: UUID
    role: Literal["viewer", "advisor", "buyer", "owner", "admin"]
```

Representative response models:

```python
class BusinessSummaryResponse(BaseModel):
    id: UUID
    name: str
    slug: str
    category: str
    district: str
    short_description: str
    status: DealStage
    financing_types: list[FinancingType]
    urgency_score: int
    popularity_score: int

class BusinessDetailResponse(BusinessSummaryResponse):
    story: BusinessStoryResponse | None
    financial_snapshot: FinancialSnapshotResponse | None
    proposals: list[FinancingProposalResponse]
    images: list[BusinessImageResponse]

class RecommendationItemResponse(BaseModel):
    business: BusinessSummaryResponse
    score: float
    reasons: list[str]
```

## 6. Auth / RBAC Model

Authentication:
- Passwords hashed with Argon2id or bcrypt.
- Short-lived JWT access token, long-lived refresh token stored server-side as a hashed token record.
- Refresh token rotation on every refresh.
- Rate limit login, register, refresh, and file upload endpoints.

RBAC rules:
- `RetailUser`: browse, follow, post memories, ask questions, create intents/investments, join groups.
- `BusinessOwner`: all RetailUser actions plus create/edit own businesses, submit listings, answer questions for own businesses.
- `GroupOrganizer`: all RetailUser actions plus create takeover groups, submit collective offers for groups they organize.
- `Admin`: full review, moderation, deal-stage management, deal-room management, audit visibility.

Ownership checks:
- Business edit requires `Admin` or `business.owner_user_id == current_user.id`.
- Business answer requires `Admin` or owner of the business.
- Deal-room document access requires `Admin` or active `deal_room_member`.
- Investment listing by business requires `Admin` or business owner.
- Group moderation requires `Admin`; group member role edits require `Admin` or organizer.

Audit-sensitive actions:
- Login failure bursts.
- Password changes and refresh-token rotation.
- Business submit/approve/reject/publish.
- Deal-stage changes.
- Investment create/confirm/cancel.
- Document upload/download/delete.
- Deal-room member add/remove.
- Admin moderation actions.

## 7. Recommendation Scoring Logic

Initial deterministic scorer:

```text
score =
  35 * interest_match
+ 20 * district_match
+ 15 * financing_type_match
+ 10 * category_match
+ 10 * normalized_popularity
+ 10 * normalized_urgency
+  5 * owner_retirement_risk
- 10 * already_invested_penalty
```

Definitions:
- `interest_match`: weighted overlap between `user_interests.category` and business category/tags.
- `district_match`: 1 if business district is in preferred districts, 0.5 if nearby district, otherwise 0.
- `financing_type_match`: 1 if proposal financing type is in user preferences.
- `category_match`: 1 for explicit category preference, 0.5 for adjacent categories.
- `normalized_popularity`: clamp business popularity score to 0..1.
- `normalized_urgency`: clamp urgency score to 0..1.
- `already_invested_penalty`: 1 if user already has confirmed investment in the business.

Response should include reason strings:
- `"Matches your interest in bakeries"`
- `"Located in Sham Shui Po, one of your preferred districts"`
- `"Open for revenue-share financing"`
- `"High urgency: owner seeking successor"`

Future upgrades:
- Add collaborative filtering once enough follows, memories, joins, and intents exist.
- Add admin-controlled boosts for verified culturally significant businesses.
- Add cold-start editorial collections for districts and categories.

## 8. Seed Data

Fictional businesses:

```python
SEED_BUSINESSES = [
    {
        "name": "Wah Kee Noodle House",
        "category": "wonton_noodles",
        "district": "Sham Shui Po",
        "short_description": "A 42-year noodle shop known for hand-folded wontons and late-night regulars.",
        "financing_types": ["revenue_share", "collective_takeover"],
        "urgency_score": 9,
        "story": {
            "founder_story": "Founded by a husband-and-wife team after arriving in the neighbourhood in the early 1980s.",
            "family_legacy": "Their children have professional careers and do not plan to operate the shop.",
            "cultural_relevance": "Regulars treat the shop as a neighbourhood canteen.",
            "neighbourhood_importance": "Nearby market workers rely on its early opening hours."
        },
        "financial_snapshot": {
            "monthly_revenue_min": 180000,
            "monthly_revenue_max": 260000,
            "monthly_profit_min": 25000,
            "monthly_profit_max": 55000,
            "monthly_rent": 68000,
            "employee_count": 5,
            "years_operating": 42,
            "funding_needed": 550000
        }
    },
    {
        "name": "Sunrise Mahjong Tile Workshop",
        "category": "crafts",
        "district": "Yau Ma Tei",
        "short_description": "A small hand-carved mahjong tile studio preserving a disappearing craft.",
        "financing_types": ["support_only", "partial_ownership"],
        "urgency_score": 8
    },
    {
        "name": "Golden Bauhinia Cha Chaan Teng",
        "category": "cha_chaan_teng",
        "district": "Mong Kok",
        "short_description": "A family-run cafe with classic pineapple buns, milk tea, and a loyal morning crowd.",
        "financing_types": ["loan", "revenue_share"],
        "urgency_score": 6
    },
    {
        "name": "Harbour Repair Radio Co.",
        "category": "electronics_repair",
        "district": "North Point",
        "short_description": "An old repair counter trusted for radios, fans, and small appliances.",
        "financing_types": ["full_acquisition", "collective_takeover"],
        "urgency_score": 10
    },
    {
        "name": "Lotus Paper Offerings",
        "category": "traditional_paper_craft",
        "district": "Sheung Wan",
        "short_description": "A second-generation paper craft shop serving families and temples across Hong Kong Island.",
        "financing_types": ["support_only", "partial_ownership"],
        "urgency_score": 7
    }
]
```

Seed users:
- `admin@local-preserve.hk` as `Admin`
- `owner.wahkee@example.com` as `BusinessOwner`
- `mei.investor@example.com` as `RetailUser`
- `sam.organizer@example.com` as `GroupOrganizer`

## 9. Docker Setup

`docker-compose.yml`:

```yaml
services:
  api:
    build:
      context: .
      dockerfile: docker/Dockerfile
    env_file: .env
    ports:
      - "8000:8000"
    depends_on:
      - db
    volumes:
      - ./app:/app/app

  db:
    image: postgres:16
    environment:
      POSTGRES_DB: local_business_investing
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app_dev_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

`docker/Dockerfile`:

```dockerfile
FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY pyproject.toml ./
RUN pip install --no-cache-dir .

COPY app ./app

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

`.env.example`:

```text
APP_ENV=local
DATABASE_URL=postgresql+psycopg://app:app_dev_password@db:5432/local_business_investing
JWT_SECRET=replace-me
JWT_ACCESS_TOKEN_MINUTES=15
JWT_REFRESH_TOKEN_DAYS=30
PASSWORD_HASH_SCHEME=argon2id
MAX_UPLOAD_BYTES=10485760
ALLOWED_UPLOAD_CONTENT_TYPES=application/pdf,image/jpeg,image/png
LOG_LEVEL=INFO
```

## 10. First GitHub Issues

1. Scaffold FastAPI backend with health check and OpenAPI metadata.
2. Add Docker Compose with PostgreSQL and API service.
3. Configure SQLAlchemy, Alembic, and initial migration.
4. Implement User, UserProfile, UserInterest models.
5. Implement auth register/login/refresh/logout with password hashing.
6. Add JWT dependency and RBAC permission helpers.
7. Implement business listing CRUD and business search filters.
8. Implement listing lifecycle: draft, submitted, approved, listed.
9. Implement business story and community memory endpoints.
10. Implement financial snapshot CRUD with validation.
11. Implement financing proposal models and term-specific tables.
12. Implement investment intent and investment creation flow.
13. Implement takeover groups, memberships, roles, and messages.
14. Implement business Q&A with owner/admin answers.
15. Implement admin review endpoints and deal-stage management.
16. Implement deal rooms, members, documents, and upload validation.
17. Implement audit logging middleware and sensitive-action logging.
18. Implement deterministic recommendation endpoint.
19. Add seed data for fictional Hong Kong businesses and users.
20. Add test suite for auth, RBAC, business lifecycle, investments, and documents.

## 11. Assumptions

- The product is a managed private marketplace, not a public securities exchange.
- Payment processing, KYC, AML, legal investor accreditation, escrow, and signed contracts are out of scope for the first backend but must be integrated before real money flows.
- Investment records represent platform-managed commitments or confirmations, not automatic settlement.
- Admins control listing approvals, funding status, and deal-stage transitions.
- Financial data may be approximate ranges and should support privacy-preserving display.
- Documents are private by default and only visible to deal-room members and admins.
- The first release can use deterministic recommendations before ML-based ranking.
- The backend will expose REST APIs consumed by a SwiftUI iOS app.
- English field names are used internally; localization can be handled by the client or later content APIs.
