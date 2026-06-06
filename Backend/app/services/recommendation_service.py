from app.models.business import Business
from app.models.user import User


def score_business_for_user(user: User, business: Business) -> tuple[float, list[str]]:
    profile = user.profile
    interests = {interest.category: interest.weight for interest in user.interests}
    preferred_districts = set(profile.preferred_districts if profile else [])
    preferred_financing_types = set(profile.preferred_financing_types if profile else [])

    score = 0.0
    reasons: list[str] = []

    if business.category in interests:
        score += 35 * min(interests[business.category], 3) / 3
        reasons.append(f"Matches your interest in {business.category}")

    if business.district in preferred_districts:
        score += 20
        reasons.append(f"Located in {business.district}, one of your preferred districts")

    if preferred_financing_types.intersection(set(business.financing_types)):
        score += 15
        reasons.append("Open for one of your preferred financing types")

    score += 10 * min(max(business.popularity_score, 0), 10) / 10
    score += 10 * min(max(business.urgency_score, 0), 10) / 10

    if business.urgency_score >= 8:
        reasons.append("High urgency: owner may need a successor soon")

    if business.owner_retirement_risk:
        score += 5
        reasons.append("Owner retirement risk is flagged")

    if not reasons:
        reasons.append("Editorially relevant local business")

    return round(score, 2), reasons
