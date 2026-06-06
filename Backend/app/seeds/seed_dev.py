from app.models.enums import FinancingType

SEED_BUSINESSES = [
    {
        "name": "Wah Kee Noodle House",
        "category": "wonton_noodles",
        "district": "Sham Shui Po",
        "short_description": "A 42-year noodle shop known for hand-folded wontons and late-night regulars.",
        "financing_types": [FinancingType.revenue_share, FinancingType.collective_takeover],
        "urgency_score": 9,
        "owner_retirement_risk": True,
    },
    {
        "name": "Sunrise Mahjong Tile Workshop",
        "category": "crafts",
        "district": "Yau Ma Tei",
        "short_description": "A small hand-carved mahjong tile studio preserving a disappearing craft.",
        "financing_types": [FinancingType.support_only, FinancingType.partial_ownership],
        "urgency_score": 8,
        "owner_retirement_risk": True,
    },
    {
        "name": "Golden Bauhinia Cha Chaan Teng",
        "category": "cha_chaan_teng",
        "district": "Mong Kok",
        "short_description": "A family-run cafe with classic pineapple buns, milk tea, and loyal regulars.",
        "financing_types": [FinancingType.loan, FinancingType.revenue_share],
        "urgency_score": 6,
        "owner_retirement_risk": False,
    },
    {
        "name": "Harbour Repair Radio Co.",
        "category": "electronics_repair",
        "district": "North Point",
        "short_description": "An old repair counter trusted for radios, fans, and small appliances.",
        "financing_types": [FinancingType.full_acquisition, FinancingType.collective_takeover],
        "urgency_score": 10,
        "owner_retirement_risk": True,
    },
]
