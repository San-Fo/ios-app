import Foundation

/// Sample, culturally specific Hong Kong businesses used by mock repositories
/// for development, SwiftUI previews and tests. NOT used in the production path.
///
/// Content ported from the HeritagHK demo data set — six fully-fleshed listings
/// that exercise every deal/takeover branch.
enum SampleData {
    static let businesses: [BusinessDetail] = [
        wongNoodleShop,
        leungTailoring,
        peakBookstore,
        shumHerbalist,
        centralBoxingGym,
        laiTeaHouse,
    ]

    static var summaries: [Business] { businesses.map(\.summary) }

    static func detail(for id: String) -> BusinessDetail? {
        guard var detail = businesses.first(where: { $0.id == id }) else { return nil }
        detail.professionalSale = professionalSale(forBusiness: id)
        return detail
    }

    private static func date(daysFromNow days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }

    private static func url(_ string: String) -> URL? { URL(string: string) }

    // MARK: 1. Wong's Hand-Pulled Noodle Shop

    static let wongNoodleShop = BusinessDetail(
        id: "biz-001",
        summary: Business(
            id: "biz-001",
            name: "Wong's Hand-Pulled Noodle Shop",
            category: .restaurant,
            district: .shamShuiPo,
            storyHeadline: "Pulling noodles by hand since 1966 — the same recipe, the same corner.",
            heroImageURL: url("https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800"),
            status: .raising,
            fundingGoal: 480_000,
            fundingRaised: 312_000,
            fundingOptions: [.revenueShare],
            yearEstablished: 1966,
            deadline: date(daysFromNow: 34),
            savedCount: 847,
            viewCount: 4_213
        ),
        tagline: "Pulling noodles by hand since 1966 — the same recipe, the same corner.",
        founderName: "Wong Kam-Cheong",
        founderStory: """
            In 1966, a 24-year-old Wong Kam-Cheong left his village in Guangdong with nothing but his father's noodle recipe and HK$200. He found a corner unit in Sham Shui Po and spent his first week sleeping on the kitchen floor, pulling noodles before dawn so they'd be ready by 7am.

            Fifty-eight years later, that same corner still smells of sesame and dried shrimp. Wong, now 82, still comes in on Wednesday mornings to watch the dough being worked — though his son manages the day-to-day. But his son is an engineer in Shenzhen, and his granddaughter is studying in London. Nobody is coming back.

            "I don't want to sell to a chain," he told us. "They'll remove the hand-pulling. The machine noodles taste different. I can tell. The customers can tell."
            """,
        whyItMatters: "Wong's is one of fewer than twelve hand-pulled noodle shops remaining in Hong Kong. Food critics, including two Michelin Bib Gourmand reviewers, have called it irreplaceable. The neighbourhood knew it as the place you ate after your grandmother's funeral, after your first day of school, after your last exam. It's not just food — it's the texture of memory.",
        communityMemories: [
            CommunityMemory(id: "mem-001", author: "Chan Siu-Yee", text: "My father brought me here every Sunday for 20 years. The wonton broth is the only thing that still tastes like my childhood.", yearsAgo: 20, authorInitials: "CY", relationship: "Regular since childhood"),
            CommunityMemory(id: "mem-002", author: "Michael Lam", text: "I interviewed Uncle Wong for a school project in 1998. He showed me how he tests the dough — he said it has to feel like an earlobe. I never forgot that.", yearsAgo: 26, authorInitials: "ML", relationship: "Neighbourhood resident"),
            CommunityMemory(id: "mem-003", author: "Priya Nair", text: "As an expat who moved here in 2019, this was the first local spot that made me feel like I belonged. The aunties behind the counter remembered my order by week three.", yearsAgo: nil, authorInitials: "PN", relationship: "Expat local regular"),
        ],
        snapshot: BusinessSnapshot(
            foundedYear: 1966,
            employees: 5,
            monthlyRevenue: 165_000,
            address: "Corner of Apliu Street, Sham Shui Po",
            highlights: ["Hand-pulled daily", "58-year legacy", "Bib Gourmand recognised"]
        ),
        useOfFunds: "Kitchen equipment replacement, ventilation upgrade, and staff wage stabilisation for 18 months.",
        revenueShareTerms: RevenueShareTerms(
            fundingTarget: 480_000,
            revenueSharePercent: 4.0,
            targetMultiple: 1.35,
            estimatedMonths: 38,
            useOfFunds: "Equipment, ventilation and working capital.",
            useOfFundsBreakdown: [
                UseOfFundsItem(label: "Equipment", percentage: 45.8),
                UseOfFundsItem(label: "Ventilation", percentage: 29.2),
                UseOfFundsItem(label: "Working Capital", percentage: 25.0),
            ],
            minimumInvestment: 2_000,
            maximumInvestment: 50_000
        ),
        partialOwnership: nil,
        fullAcquisition: nil,
        hasTakeoverGroup: false,
        galleryImageURLs: [
            url("https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800"),
            url("https://images.unsplash.com/photo-1585032226651-759b368d7246?w=800"),
        ].compactMap { $0 },
        shareRewards: [
            ShareReward(cardsRequired: 1, title: "Supporter's thank-you postcard", detail: "A hand-written note from Uncle Wong."),
            ShareReward(cardsRequired: 5, title: "A free bowl of noodles each month", detail: "Drop by any time — your bowl is on the house."),
            ShareReward(cardsRequired: 10, title: "Name on the supporters' wall", detail: "Your name painted on the wall of regulars."),
            ShareReward(cardsRequired: 25, title: "A morning learning to pull noodles", detail: "A private session with Uncle Wong at dawn."),
        ]
    )

    // MARK: 2. Leung's Master Tailoring

    static let leungTailoring = BusinessDetail(
        id: "biz-002",
        summary: Business(
            id: "biz-002",
            name: "Leung's Master Tailoring",
            category: .tailoring,
            district: .centralWestern,
            storyHeadline: "Bespoke suits for Hong Kong's boardrooms since 1979.",
            heroImageURL: url("https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=800"),
            status: .seekingBuyer,
            fundingGoal: 2_200_000,
            fundingRaised: 0,
            fundingOptions: [.partialOwnership, .fullAcquisition, .takeoverGroup],
            yearEstablished: 1979,
            savedCount: 523,
            viewCount: 2_891
        ),
        tagline: "Bespoke suits for Hong Kong's boardrooms since 1979.",
        founderName: "Leung Po-Wah",
        founderStory: """
            Leung Po-Wah learned tailoring under a Shanghai master in the 1970s and opened his Central atelier in 1979, at 28. He has dressed three generations of Hong Kong's banking and legal elite. His client book reads like a who's who of the city's history.

            He is 73 now and his hands are still steady. But his daughter is a doctor and his son runs a restaurant in Toronto. He has one apprentice — a young man from Nepal who has been with him for six years and knows the craft but not the clients.

            "The suit is only part of what I sell," Po-Wah says. "I sell trust. A new owner needs to earn that. I want to find someone who respects what I built, not someone who will turn it into a tourist shop."
            """,
        whyItMatters: "Leung's is one of Hong Kong's last true bespoke tailoring houses with an active apprenticeship. Most have converted to semi-made or closed entirely. His archive of 1,200 client patterns — some dating to 1981 — is a textile history of the city's professional class.",
        communityMemories: [
            CommunityMemory(id: "mem-004", author: "Raymond Cheung", text: "My wedding suit, my son's wedding suit, and hopefully my grandson's — all from Uncle Leung. He remembers every measurement without looking it up.", yearsAgo: 35, authorInitials: "RC", relationship: "Client since 1989"),
        ],
        snapshot: BusinessSnapshot(
            foundedYear: 1979,
            employees: 3,
            monthlyRevenue: 185_000,
            address: "Central, Hong Kong Island",
            highlights: ["1,200 client patterns archived", "Active apprenticeship", "45-year institution"]
        ),
        useOfFunds: "Ownership transition and structured handover.",
        revenueShareTerms: nil,
        partialOwnership: PartialOwnershipOption(
            equityOfferedPercent: 40,
            valuation: 2_250_000,
            minimumInvestment: 225_000,
            existingInvestors: 0
        ),
        fullAcquisition: FullAcquisitionOption(
            askingPrice: 2_200_000,
            openToGroupOffer: true,
            includes: ["Client archive", "Brand", "Equipment", "12-month handover"],
            includesProperty: false,
            leaseYearsRemaining: 4,
            monthlyRevenue: 185_000,
            staffCount: 3,
            ownerWillingToStay: true,
            handoverMonths: 12
        ),
        hasTakeoverGroup: true,
        galleryImageURLs: [
            url("https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=800"),
            url("https://images.unsplash.com/photo-1558769132-cb1aea458c5e?w=800"),
        ].compactMap { $0 }
    )

    // MARK: 3. The Peak Bookstore (URGENT)

    static let peakBookstore = BusinessDetail(
        id: "biz-003",
        summary: Business(
            id: "biz-003",
            name: "The Peak Bookstore",
            category: .bookstore,
            district: .wanChai,
            storyHeadline: "Hong Kong's most loved independent bookstore — threatened by rising rent.",
            heroImageURL: url("https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800"),
            status: .urgentRisk,
            fundingGoal: 360_000,
            fundingRaised: 89_000,
            fundingOptions: [.revenueShare],
            yearEstablished: 1993,
            deadline: date(daysFromNow: 19),
            savedCount: 1_204,
            viewCount: 7_891
        ),
        tagline: "Hong Kong's most loved independent bookstore — threatened by rising rent.",
        founderName: "Amy Tsang",
        founderStory: """
            Amy Tsang opened The Peak Bookstore in 1993 when she was 29, after a decade working in publishing in London. She came back to Hong Kong with 2,000 books and a belief that the city deserved a bookstore that stocked both English and Chinese literature with equal care.

            Thirty-one years later, The Peak has become a gathering place — hosting over 400 author events, a monthly reading group, and a children's corner that has introduced thousands of Wan Chai kids to books. Amy is 60 now, healthy, and not ready to stop. But the landlord has just proposed a 65% rent increase.

            "I don't need to be rescued," she says. "I need breathing room. I need partners who believe in what this place means to the neighbourhood."
            """,
        whyItMatters: "Independent bookstores in Hong Kong have declined by over 60% since 2010. The Peak is one of the last bilingual independents with a genuine community programme. Its Wan Chai reading group has been running for 19 consecutive years. Authors from across Asia treat it as a home venue.",
        communityMemories: [
            CommunityMemory(id: "mem-005", author: "Jessica Ho", text: "I met my best friend at a book event here in 2011. We've been coming back every month since. The Peak isn't just a bookstore — it's where I grew up intellectually.", yearsAgo: 13, authorInitials: "JH", relationship: "Reading group member"),
            CommunityMemory(id: "mem-006", author: "Timothy Chan", text: "Amy personally recommended five books that changed how I think about my city. She knows every customer's reading history. You can't automate that.", yearsAgo: 7, authorInitials: "TC", relationship: "Regular customer"),
        ],
        snapshot: BusinessSnapshot(
            foundedYear: 1993,
            employees: 4,
            monthlyRevenue: 95_000,
            address: "Wan Chai, Hong Kong Island",
            highlights: ["400+ author events", "19-year reading group", "Bilingual independent"]
        ),
        useOfFunds: "Cover 18 months of increased rent while Amy restructures the business model and secures long-term sustainability.",
        revenueShareTerms: RevenueShareTerms(
            fundingTarget: 360_000,
            revenueSharePercent: 2.5,
            targetMultiple: 1.2,
            estimatedMonths: 48,
            useOfFunds: "Rent buffer, events programme and working capital.",
            useOfFundsBreakdown: [
                UseOfFundsItem(label: "Rent Buffer", percentage: 77.8),
                UseOfFundsItem(label: "Events Programme", percentage: 13.9),
                UseOfFundsItem(label: "Working Capital", percentage: 8.3),
            ],
            minimumInvestment: 500,
            maximumInvestment: 30_000
        ),
        partialOwnership: nil,
        fullAcquisition: nil,
        hasTakeoverGroup: false,
        galleryImageURLs: [
            url("https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800"),
            url("https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=800"),
        ].compactMap { $0 }
    )

    // MARK: 4. Shum's Traditional Herbalist

    static let shumHerbalist = BusinessDetail(
        id: "biz-004",
        summary: Business(
            id: "biz-004",
            name: "Shum's Traditional Herbalist",
            category: .herbalist,
            district: .kowloonCity,
            storyHeadline: "Three generations of healing, one family recipe passed down in secret.",
            heroImageURL: url("https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=800"),
            status: .seekingBuyer,
            fundingGoal: 1_600_000,
            fundingRaised: 0,
            fundingOptions: [.fullAcquisition],
            yearEstablished: 1954,
            savedCount: 412,
            viewCount: 1_943
        ),
        tagline: "Three generations of healing, one family recipe passed down in secret.",
        founderName: "Shum Kwok-Fai (3rd generation)",
        founderStory: """
            Shum's Herbalist was founded in 1954 by Shum Yat-Ming, who brought his formulas from Fujian. His son expanded the shop in the 1980s; his grandson Kwok-Fai now runs it at 58. He has two daughters, both professionals in their 30s, neither interested in the family trade.

            Kwok-Fai is not sad about this — he's matter-of-fact. "The knowledge took 70 years to accumulate. I would rather it continued under someone else than disappeared." He is offering to teach his formulas and sourcing network to a buyer or investor who will keep the practice authentic.
            """,
        whyItMatters: "Traditional Chinese herbalism is a living medical tradition with centuries of accumulated knowledge. Shum's is notable for its proprietary blends for respiratory conditions and digestive health. It serves over 200 regular patients monthly, many elderly, with nowhere else to go for this type of care.",
        communityMemories: [
            CommunityMemory(id: "mem-007", author: "Mei-Ling Wu", text: "My grandmother swore by Shum's cough blend. When she passed, I started going myself. I've been going for 15 years. It's not just medicine — it's continuity.", yearsAgo: 15, authorInitials: "MW", relationship: "Family legacy customer"),
        ],
        snapshot: BusinessSnapshot(
            foundedYear: 1954,
            employees: 2,
            monthlyRevenue: 95_000,
            address: "Kowloon City",
            highlights: ["70-year legacy", "Proprietary blends", "200+ monthly patients"]
        ),
        useOfFunds: "Acquisition with a 24-month apprenticeship handover.",
        revenueShareTerms: nil,
        partialOwnership: nil,
        fullAcquisition: FullAcquisitionOption(
            askingPrice: 1_600_000,
            openToGroupOffer: false,
            includes: ["Herbal inventory", "Sourcing contacts", "Proprietary blend records", "24-month apprenticeship"],
            includesProperty: false,
            leaseYearsRemaining: 6,
            monthlyRevenue: 95_000,
            staffCount: 2,
            ownerWillingToStay: true,
            handoverMonths: 24
        ),
        hasTakeoverGroup: false,
        galleryImageURLs: [url("https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=800")].compactMap { $0 }
    )

    // MARK: 5. Central Boxing Gym

    static let centralBoxingGym = BusinessDetail(
        id: "biz-005",
        summary: Business(
            id: "biz-005",
            name: "Central Boxing Gym",
            category: .gym,
            district: .yauTsimMong,
            storyHeadline: "Where Kowloon's kids learned discipline — and a few became champions.",
            heroImageURL: url("https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800"),
            status: .raising,
            fundingGoal: 650_000,
            fundingRaised: 430_000,
            fundingOptions: [.revenueShare, .partialOwnership],
            yearEstablished: 1986,
            deadline: date(daysFromNow: 27),
            savedCount: 934,
            viewCount: 5_122
        ),
        tagline: "Where Kowloon's kids learned discipline — and a few became champions.",
        founderName: "Coach Benny Ng",
        founderStory: """
            Benny Ng opened his gym in 1986 after a career as a semi-professional boxer. He has trained four Hong Kong Boxing Championships winners and coached over 3,000 young people from the Yau Tsim Mong area. His gym charges below-market rates deliberately — "This neighbourhood has kids who need somewhere to go. I'm not running a luxury fitness club."

            At 68, his knees are giving out. He can still coach but can't manage the business day-to-day. His son has no interest. His star former pupil, now 35, has expressed interest in taking over — but doesn't have the capital.
            """,
        whyItMatters: "Central Boxing Gym has functioned as a de facto youth programme in one of Hong Kong's densest urban districts. Police officers, teachers, and social workers have all referred at-risk youth here. It is a community anchor with an outsized social impact that cannot be replicated by a franchise gym.",
        communityMemories: [
            CommunityMemory(id: "mem-008", author: "Marcus Yip", text: "I was 14 and heading nowhere good when my teacher sent me to Coach Benny. I'm 31 now with a stable job. I think about him every day.", yearsAgo: 17, authorInitials: "MY", relationship: "Former student"),
            CommunityMemory(id: "mem-009", author: "Karen Cheung", text: "My two sons trained here. The discipline they learned changed their whole approach to life. Coach Benny is the most important person outside our family.", yearsAgo: 8, authorInitials: "KC", relationship: "Parent of students"),
        ],
        snapshot: BusinessSnapshot(
            foundedYear: 1986,
            employees: 4,
            monthlyRevenue: 140_000,
            address: "Yau Tsim Mong, Kowloon",
            highlights: ["4 championship winners", "3,000+ youth coached", "Community anchor"]
        ),
        useOfFunds: "Fund the management buyout for Coach Benny's former pupil Danny, enabling continuity of the gym's community mission.",
        revenueShareTerms: RevenueShareTerms(
            fundingTarget: 650_000,
            revenueSharePercent: 5.0,
            targetMultiple: 1.3,
            estimatedMonths: 30,
            useOfFunds: "Buyout payment, equipment refresh and working capital.",
            useOfFundsBreakdown: [
                UseOfFundsItem(label: "Buyout Payment", percentage: 76.9),
                UseOfFundsItem(label: "Equipment Refresh", percentage: 15.4),
                UseOfFundsItem(label: "Working Capital", percentage: 7.7),
            ],
            minimumInvestment: 1_000,
            maximumInvestment: 80_000
        ),
        partialOwnership: PartialOwnershipOption(
            equityOfferedPercent: 25,
            valuation: 1_400_000,
            minimumInvestment: 70_000,
            existingInvestors: 3
        ),
        fullAcquisition: nil,
        hasTakeoverGroup: false,
        galleryImageURLs: [url("https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800")].compactMap { $0 },
        shareRewards: [
            ShareReward(cardsRequired: 1, title: "Supporter's gym tote bag"),
            ShareReward(cardsRequired: 5, title: "A free month of membership", detail: "Train with the next generation."),
            ShareReward(cardsRequired: 10, title: "Personal session with Coach Danny"),
            ShareReward(cardsRequired: 20, title: "Your name on the champions' board", detail: "Alongside the gym's title winners."),
        ]
    )

    // MARK: 6. Lai's Milk Tea House

    static let laiTeaHouse = BusinessDetail(
        id: "biz-006",
        summary: Business(
            id: "biz-006",
            name: "Lai's Milk Tea House",
            category: .teaHouse,
            district: .eastern,
            storyHeadline: "The smoothest silk-stocking milk tea in Hong Kong — and the most stubborn recipe.",
            heroImageURL: url("https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=800"),
            status: .seekingBuyer,
            fundingGoal: 1_400_000,
            fundingRaised: 0,
            fundingOptions: [.partialOwnership, .fullAcquisition, .takeoverGroup],
            yearEstablished: 1972,
            savedCount: 1_891,
            viewCount: 11_204
        ),
        tagline: "The smoothest silk-stocking milk tea in Hong Kong — and the most stubborn recipe.",
        founderName: "Lai Suet-Ying",
        founderStory: """
            Lai Suet-Ying has been making milk tea since 1972. She is 80 years old, still arrives at 5am, and refuses to change her method. The tea is strained through a silk stocking — the traditional cha chaan teng way — and has won three consecutive awards from Hong Kong's Milk Tea Association.

            Her two granddaughters help on weekends. They've started a social media account without her knowledge — it now has 40,000 followers. Neither wants to leave their careers to run the shop full-time. But they don't want to see it close either.

            "Someone will love this as much as me," she says. "I just haven't met them yet."
            """,
        whyItMatters: "Cha chaan teng culture is UNESCO-recognised as part of Hong Kong's intangible cultural heritage. Lai's is one of the authentic surviving practitioners of silk-stocking tea, an art form being gradually replaced by machine brewing. The shop is a cultural artefact as much as a business.",
        communityMemories: [
            CommunityMemory(id: "mem-010", author: "Gary Fong", text: "I've had milk tea across 30 countries. Nothing comes close to Lai's. It's not nostalgia — it's chemistry. The texture is genuinely different.", yearsAgo: nil, authorInitials: "GF", relationship: "Food journalist"),
        ],
        snapshot: BusinessSnapshot(
            foundedYear: 1972,
            employees: 4,
            monthlyRevenue: 110_000,
            address: "Eastern District, Hong Kong Island",
            highlights: ["Silk-stocking method", "3× Milk Tea Association awards", "40k social following"]
        ),
        useOfFunds: "Ownership transition with a personal apprenticeship in the silk-stocking method.",
        revenueShareTerms: nil,
        partialOwnership: PartialOwnershipOption(
            equityOfferedPercent: 51,
            valuation: 1_570_000,
            minimumInvestment: 235_000,
            existingInvestors: 1
        ),
        fullAcquisition: FullAcquisitionOption(
            askingPrice: 1_400_000,
            openToGroupOffer: true,
            includes: ["Brand", "Recipe & method", "6-month apprenticeship", "Staff"],
            includesProperty: false,
            leaseYearsRemaining: 5,
            monthlyRevenue: 110_000,
            staffCount: 4,
            ownerWillingToStay: true,
            handoverMonths: 6
        ),
        hasTakeoverGroup: true,
        galleryImageURLs: [url("https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=800")].compactMap { $0 },
        shareRewards: [
            ShareReward(cardsRequired: 1, title: "A cup of silk-stocking milk tea, on us"),
            ShareReward(cardsRequired: 5, title: "Lai's signature tea leaves, monthly"),
            ShareReward(cardsRequired: 15, title: "A tea-making lesson with Suet-Ying", detail: "Learn the silk-stocking method by hand."),
        ]
    )

    // MARK: - Takeover groups

    static let takeoverGroups: [TakeoverGroup] = [
        TakeoverGroup(
            id: "tg-002",
            businessId: "biz-002",
            businessName: "Leung's Master Tailoring",
            memberCount: 4,
            targetMembers: 3,
            pooledCommitment: 2_000_000,
            members: [
                GroupMember(id: "u1", name: "David L.", role: .lead, committedAmount: 800_000),
                GroupMember(id: "u2", name: "Sarah K.", role: .contributor, committedAmount: 700_000),
                GroupMember(id: "u3", name: "Eric T.", role: .contributor, committedAmount: 500_000),
                GroupMember(id: "u4", name: "Nadia R.", role: .advisor, committedAmount: nil),
            ],
            channels: [
                GroupChannel(id: "c1", name: "general", topic: "Coordinating our offer for Leung's", messages: [
                    GroupMessage(id: "g1", authorName: "David L.", text: "Welcome all. Po-Wah wants a partner who respects the craft — let's lead with that.", sentAt: Date().addingTimeInterval(-7200), isCurrentUser: false),
                    GroupMessage(id: "g2", authorName: "Sarah K.", text: "Financials look solid. Lease has 4 years — we should negotiate renewal terms.", sentAt: Date().addingTimeInterval(-3600), isCurrentUser: false),
                ]),
                GroupChannel(id: "c2", name: "due-diligence", topic: "Reviewing the books and the client archive", messages: []),
                GroupChannel(id: "c3", name: "financing", topic: "Structuring the collective offer", messages: []),
                GroupChannel(id: "c4", name: "founders-qa", topic: "Questions for Po-Wah", messages: []),
            ],
            founderQAndA: [
                FounderQA(id: "q1", question: "Will Po-Wah stay on for the full 12-month handover?", answer: "Yes, he has committed to a structured 12-month on-site handover.", askedBy: "David L."),
                FounderQA(id: "q2", question: "Is the Nepalese apprentice staying with the business?", answer: nil, askedBy: "Sarah K."),
            ],
            status: .negotiating,
            roles: [
                TakeoverRole(title: "Operations Lead", detail: "Day-to-day management, client relationships", isFilled: true, occupantName: "David L."),
                TakeoverRole(title: "Finance Lead", detail: "Business financials, investor reporting", isFilled: true, occupantName: "Sarah K."),
                TakeoverRole(title: "Silent Investor", detail: "Financial contribution, non-operational", isFilled: false),
            ],
            collectiveOfferAmount: 2_000_000
        ),
        TakeoverGroup(
            id: "tg-006",
            businessId: "biz-006",
            businessName: "Lai's Milk Tea House",
            memberCount: 7,
            targetMembers: 5,
            pooledCommitment: 1_350_000,
            members: [
                GroupMember(id: "v1", name: "Alice T.", role: .lead, committedAmount: 400_000),
                GroupMember(id: "v2", name: "Ben W.", role: .contributor, committedAmount: 300_000),
                GroupMember(id: "v3", name: "Chloe M.", role: .contributor, committedAmount: 250_000),
                GroupMember(id: "v4", name: "Daniel P.", role: .member, committedAmount: 200_000),
            ],
            channels: [
                GroupChannel(id: "d1", name: "general", topic: "Preserving Lai's together", messages: [
                    GroupMessage(id: "h1", authorName: "Alice T.", text: "Suet-Ying agreed to a 6-month apprenticeship. Ben will lead on the recipe.", sentAt: Date().addingTimeInterval(-10800), isCurrentUser: false),
                ]),
                GroupChannel(id: "d2", name: "due-diligence", topic: "Lease, books, equipment", messages: []),
                GroupChannel(id: "d3", name: "tea-recipe-handover", topic: "Documenting the silk-stocking method", messages: []),
                GroupChannel(id: "d4", name: "founders-qa", topic: "Questions for Suet-Ying", messages: []),
            ],
            founderQAndA: [
                FounderQA(id: "r1", question: "Will the granddaughters keep running the social account?", answer: "Yes — they've agreed to stay on as brand advisors.", askedBy: "Chloe M."),
            ],
            status: .dueDiligence,
            roles: [
                TakeoverRole(title: "Lead Operator", detail: "Day-to-day operations, staff management", isFilled: true, occupantName: "Alice T."),
                TakeoverRole(title: "Tea Master Apprentice", detail: "Learn Suet-Ying's method, lead production", isFilled: true, occupantName: "Ben W."),
                TakeoverRole(title: "Marketing & Community", detail: "Social, brand, community events", isFilled: true, occupantName: "Chloe M."),
                TakeoverRole(title: "Silent Investor", detail: "Capital contribution only", isFilled: false),
            ],
            collectiveOfferAmount: 1_350_000
        ),
    ]

    static func group(forBusiness businessId: String) -> TakeoverGroup? {
        takeoverGroups.first { $0.businessId == businessId }
    }

    // MARK: - Portfolio sample (for Profile preview / mock)

    static let sampleInvestments: [InvestmentRecord] = [
        InvestmentRecord(id: "inv-1", businessId: "biz-001", businessName: "Wong's Hand-Pulled Noodle Shop", kind: .revenueShare, amount: 10_000, date: Calendar.current.date(byAdding: .month, value: -4, to: Date()) ?? Date(), status: .repaying, returnedAmount: 1_800, expectedReturn: 13_500, supportCards: 5),
        InvestmentRecord(id: "inv-2", businessId: "biz-005", businessName: "Central Boxing Gym", kind: .partialOwnership, amount: 70_000, date: Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date(), status: .active, returnedAmount: 0, expectedReturn: nil, supportCards: 12),
        InvestmentRecord(id: "inv-3", businessId: "biz-003", businessName: "The Peak Bookstore", kind: .revenueShare, amount: 2_500, date: Calendar.current.date(byAdding: .day, value: -20, to: Date()) ?? Date(), status: .active, returnedAmount: 0, expectedReturn: 3_000, supportCards: 1),
    ]

    // MARK: - Submitted business sales (AI-screened, commercial-first)

    static let professionalSales: [ProfessionalSale] = [
        ProfessionalSale(
            id: "sale-002",
            businessId: "biz-002",
            businessName: "Leung's Master Tailoring",
            stage: .commercialBidding,
            askingPrice: 2_200_000,
            aiEvaluation: SaleEvaluation(
                score: 91,
                verdict: .recommendedForCommercialBidding,
                strengths: ["High-margin repeat clientele", "Defensible craft process", "Owner handover available"],
                risks: ["Key-person transition", "Lease assignment required"],
                summary: "Backend AI flags this as a strong acquisition candidate, so it is offered to commercial investors first. Margins are well above category average and the client archive creates durable switching costs.",
                recommendedAction: "Move to bid. Prioritise securing the 12-month handover and lease assignment in your terms.",
                confidence: 0.88
            ),
            commercialBiddingEndsAt: Date().addingTimeInterval(86400 * 5),
            financials: SaleFinancials(
                annualRevenue: 2_220_000,
                annualProfit: 540_000,
                monthlyRent: 48_000,
                leaseYearsRemaining: 4,
                staffCount: 3,
                inventoryValue: 180_000,
                notes: "Established Central clientele (1,200 active client patterns). Strong repeat custom from banking & legal sector. One trained apprentice retained. Owner available for a 12-month handover."
            ),
            includes: ["Client archive", "Brand & goodwill", "Equipment", "Lease assignment", "12-month handover"],
            ownerWillingToStay: true,
            handoverMonths: 12,
            retailFallbackOffer: nil,
            bids: [
                SaleBid(id: "bid-1", bidderName: "Heritage Atelier Group", bidderCredential: "Acquired 3 craft houses", amount: 1_950_000, message: "We preserve the master's name and keep the apprenticeship.", date: Date().addingTimeInterval(-86400 * 6), status: .submitted),
                SaleBid(id: "bid-2", bidderName: "M. Cheng (independent)", bidderCredential: "Ex-LVMH operations", amount: 2_050_000, message: "Committed to the bespoke model, no tourist conversion.", date: Date().addingTimeInterval(-86400 * 2), status: .submitted),
            ]
        ),
        ProfessionalSale(
            id: "sale-004",
            businessId: "biz-004",
            businessName: "Shum's Traditional Herbalist",
            stage: .openToRetail,
            askingPrice: 1_600_000,
            aiEvaluation: SaleEvaluation(
                score: 78,
                verdict: .recommendedForCommercialBidding,
                strengths: ["Recurring patients", "Rare formula knowledge", "Long handover available"],
                risks: ["Specialist operator required", "Inventory verification needed"],
                summary: "Commercial bidding completed, but the owner declined the bids and opened a retail fallback path. Recurring patient revenue is stable; value hinges on retaining the formula knowledge through the apprenticeship.",
                recommendedAction: "Only pursue with a qualified TCM operator. Verify inventory and secure the 24-month apprenticeship before committing.",
                confidence: 0.74
            ),
            commercialBiddingEndsAt: Date().addingTimeInterval(-86400 * 3),
            financials: SaleFinancials(
                annualRevenue: 1_140_000,
                annualProfit: 312_000,
                monthlyRent: 26_000,
                leaseYearsRemaining: 6,
                staffCount: 2,
                inventoryValue: 240_000,
                notes: "200+ regular monthly patients. Proprietary blend records and a sourcing network included. 24-month apprenticeship with the 3rd-generation owner to transfer the formulas."
            ),
            includes: ["Herbal inventory", "Proprietary blend records", "Sourcing network", "24-month apprenticeship"],
            ownerWillingToStay: true,
            handoverMonths: 24,
            retailFallbackOffer: RetailFallbackOffer(
                askingPrice: 1_850_000,
                allowOutrightPurchase: true,
                allowGroupTakeover: true,
                ownerNote: "Commercial offers were too low. The family is willing to try a public buyer or a community takeover group at this price."
            ),
            bids: [
                SaleBid(id: "bid-4", bidderName: "Kowloon Wellness Holdings", bidderCredential: "TCM clinic operator", amount: 1_360_000, message: "We can retain the apprentice but would rebrand the shop.", date: Date().addingTimeInterval(-86400 * 8), status: .rejected)
            ],
            groupOffers: [
                GroupBuyOffer(id: "go-1", groupId: "tg-004", groupName: "Kowloon City Heritage Circle", memberCount: 42, amount: 1_620_000, message: "A community group of long-time patients and neighbours who want to keep the shop exactly as it is, with the apprenticeship intact.", date: Date().addingTimeInterval(-86400 * 1), status: .submitted)
            ]
        ),
    ]

    static func professionalSale(forBusiness businessId: String) -> ProfessionalSale? {
        professionalSales.first { $0.businessId == businessId }
    }
}
