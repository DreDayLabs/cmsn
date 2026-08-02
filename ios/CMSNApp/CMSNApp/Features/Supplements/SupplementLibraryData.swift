import Foundation

/// The fixed, static supplement education library. No personalization logic
/// reads or writes this — it's a library the athlete browses, not a
/// recommendation CMSN pushes at them. Every `mayHelpSupport` bullet is
/// worded in hedged language on purpose; see `SupplementDisclaimer` and the
/// non-negotiable copy rule in the plan.
///
/// `lastReviewed` dates are placeholders for this initial ship — a real
/// content-review process (with a named reviewer) should update these dates
/// whenever the copy changes, per the product doc's "last review date" field.
enum SupplementLibraryData {
    static let entries: [SupplementEducationEntry] = [
        SupplementEducationEntry(
            id: "creatine-monohydrate",
            name: "Creatine Monohydrate",
            whatItIs: "A naturally occurring compound stored in muscle tissue, also available as a low-cost, heavily studied supplement.",
            mayHelpSupport: [
                "May help support strength and power output during short, high-effort training.",
                "May help support training volume across a session.",
                "Widely studied — one of the most-researched supplements in sports nutrition."
            ],
            evidenceLevel: .strong,
            commonForms: ["Powder", "Capsules"],
            labelUseReminder: "Follow the amount and timing on the product label — CMSN does not set a personalized dose.",
            cautions: [
                "Some people report mild water retention when starting.",
                "Drink water consistently while using it."
            ],
            consultProfessionalWhen: ["You have kidney concerns.", "You're on medication that affects kidney function.", "You're pregnant or nursing."],
            sourceReferences: ["International Society of Sports Nutrition position stand on creatine (general reference — verify current version before citing in-app)"],
            lastReviewed: Date(timeIntervalSince1970: 1_735_689_600) // 2025-01-01 placeholder
        ),
        SupplementEducationEntry(
            id: "protein-powder",
            name: "Protein Powder (Whey / Plant-Based)",
            whatItIs: "A concentrated protein source used to help hit a daily protein target when whole food alone doesn't cover it.",
            mayHelpSupport: [
                "May help support reaching a daily protein target conveniently.",
                "May help support muscle recovery as part of an overall adequate-protein diet."
            ],
            evidenceLevel: .strong,
            commonForms: ["Powder (whey, casein, pea, soy blends)", "Ready-to-drink shakes"],
            labelUseReminder: "Use the serving size on the label; protein needs are about your total daily intake, not any single shake.",
            cautions: ["Whey-based products contain dairy.", "Check for lactose or specific allergens if sensitive."],
            consultProfessionalWhen: ["You have a diagnosed kidney condition.", "You have a known dairy or soy allergy and are unsure about a product's sourcing."],
            sourceReferences: ["General sports-nutrition literature on protein timing and totals (verify current consensus before citing in-app)"],
            lastReviewed: Date(timeIntervalSince1970: 1_735_689_600)
        ),
        SupplementEducationEntry(
            id: "caffeine",
            name: "Caffeine",
            whatItIs: "A common stimulant found in coffee, tea, and pre-workout products, used to reduce perceived effort and increase alertness before training.",
            mayHelpSupport: [
                "May help support alertness and reduce perceived effort during training.",
                "May help support performance in some endurance and strength contexts."
            ],
            evidenceLevel: .moderate,
            commonForms: ["Coffee", "Tea", "Capsules", "Pre-workout blends"],
            labelUseReminder: "Follow label guidance on serving size and timing; total daily caffeine adds up across coffee, tea, and other products.",
            cautions: [
                "Can affect sleep if taken late in the day.",
                "Can increase heart rate or cause jitteriness in sensitive individuals."
            ],
            consultProfessionalWhen: ["You have a heart condition or high blood pressure.", "You're pregnant or nursing.", "You're sensitive to stimulants."],
            sourceReferences: ["General sports-nutrition literature on caffeine and exercise performance (verify current consensus before citing in-app)"],
            lastReviewed: Date(timeIntervalSince1970: 1_735_689_600)
        ),
        SupplementEducationEntry(
            id: "electrolytes",
            name: "Electrolytes",
            whatItIs: "Minerals like sodium, potassium, and magnesium lost through sweat during training, replaced through food, water, or electrolyte products.",
            mayHelpSupport: [
                "May help support hydration during longer or sweatier sessions.",
                "May help support how you feel during and after intense training in heat."
            ],
            evidenceLevel: .moderate,
            commonForms: ["Powder packets", "Tablets", "Ready-to-drink"],
            labelUseReminder: "Follow the label — more sodium isn't automatically better, especially if you're managing blood pressure.",
            cautions: ["People managing blood pressure should be mindful of added sodium."],
            consultProfessionalWhen: ["You're on a sodium-restricted diet.", "You have kidney or heart conditions."],
            sourceReferences: ["General hydration and sports-nutrition guidance (verify current consensus before citing in-app)"],
            lastReviewed: Date(timeIntervalSince1970: 1_735_689_600)
        ),
        SupplementEducationEntry(
            id: "omega-3",
            name: "Omega-3 / Fish Oil",
            whatItIs: "Essential fatty acids (EPA/DHA) found in fatty fish and available as a supplement for people who don't eat much fish.",
            mayHelpSupport: [
                "May help support overall wellness as part of a balanced diet.",
                "Some people use it alongside training for general joint/recovery comfort — evidence here is mixed."
            ],
            evidenceLevel: .limited,
            commonForms: ["Softgels", "Liquid", "Algae-based (vegan) options"],
            labelUseReminder: "Follow the label serving size.",
            cautions: ["Can interact with blood-thinning medication."],
            consultProfessionalWhen: ["You're on blood thinners or have a bleeding disorder.", "You have a seafood allergy and are considering a fish-oil (not algae-based) product."],
            sourceReferences: ["General nutrition literature on omega-3 fatty acids (verify current consensus before citing in-app)"],
            lastReviewed: Date(timeIntervalSince1970: 1_735_689_600)
        ),
        SupplementEducationEntry(
            id: "vitamin-d",
            name: "Vitamin D",
            whatItIs: "A vitamin the body partly produces from sun exposure, also available through food and supplements — commonly low in people with limited sun exposure.",
            mayHelpSupport: [
                "May help support normal levels in people with limited sun exposure.",
                "May help support overall wellness as part of a balanced diet."
            ],
            evidenceLevel: .moderate,
            commonForms: ["Softgels", "Drops", "Gummies"],
            labelUseReminder: "Follow the label serving size — vitamin D can build up in the body over time at high doses.",
            cautions: ["Very high doses over long periods can cause issues — this is not a 'more is better' supplement."],
            consultProfessionalWhen: ["You want to know your actual vitamin D level (a blood test, not a guess, is the right way to find out).", "You're considering a high-dose product."],
            sourceReferences: ["General nutrition literature on vitamin D (verify current consensus before citing in-app)"],
            lastReviewed: Date(timeIntervalSince1970: 1_735_689_600)
        ),
    ]
}
