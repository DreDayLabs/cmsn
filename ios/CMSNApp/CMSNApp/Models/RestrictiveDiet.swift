import Foundation

/// Stable ids for the locked restrictive-diet list. Raw values are the
/// persistence key. Do not rename them once a profile has been saved.
enum RestrictiveDietID: String, Codable, CaseIterable, Identifiable, Hashable {
    case none
    case danielFast = "daniel_fast"
    case keto
    case carnivore
    case vegan
    case vegetarian
    case drSebi = "dr_sebi"
    case mediterranean
    case paleo
    case whole30
    case pescatarian
    case flexitarian
    case intermittentFasting = "intermittent_fasting"
    case highProtein = "high_protein"
    case lowCarb = "low_carb"

    var id: String { rawValue }

    /// The 14 named patterns. `none` is the explicit "not on a restrictive diet" answer.
    static var named: [RestrictiveDietID] { allCases.filter { $0 != .none } }

    var displayName: String {
        switch self {
        case .none: return "None / not on a restrictive diet"
        case .danielFast: return "Daniel Fast (Daniel's diet)"
        case .keto: return "Keto"
        case .carnivore: return "Carnivore"
        case .vegan: return "Vegan"
        case .vegetarian: return "Vegetarian"
        case .drSebi: return "Dr. Sebi (alkaline)"
        case .mediterranean: return "Mediterranean"
        case .paleo: return "Paleo"
        case .whole30: return "Whole30"
        case .pescatarian: return "Pescatarian"
        case .flexitarian: return "Flexitarian (mostly plants, some meat)"
        case .intermittentFasting: return "Intermittent fasting"
        case .highProtein: return "High-protein (athlete / body-recomp)"
        case .lowCarb: return "Low-carb (not full keto)"
        }
    }
}

/// Sub-option for intermittent fasting. Stored only while that diet is selected.
enum FastingWindow: String, Codable, CaseIterable, Identifiable, Hashable {
    case sixteenEight = "16_8"
    case omad

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sixteenEight: return "16:8"
        case .omad: return "OMAD"
        }
    }
}

/// What the athlete picked. Empty means they have not answered.
/// `none` is exclusive: it clears every named diet, and a named diet clears it.
struct NutritionDietSelection: Equatable {
    var dietIDs: [RestrictiveDietID]
    var fastingWindow: FastingWindow?

    static let unanswered = NutritionDietSelection(dietIDs: [], fastingWindow: nil)

    var isUnanswered: Bool { dietIDs.isEmpty }

    init(dietIDs: [RestrictiveDietID], fastingWindow: FastingWindow?) {
        let ordered = RestrictiveDietCatalog.ordered(dietIDs)
        let cleaned = ordered.contains(.none) ? [RestrictiveDietID.none] : ordered
        self.dietIDs = cleaned
        if cleaned.contains(.intermittentFasting) {
            self.fastingWindow = fastingWindow ?? .sixteenEight
        } else {
            self.fastingWindow = nil
        }
    }

    init(rawDietIDs: [String], fastingWindowRaw: String?) {
        self.init(
            dietIDs: rawDietIDs.compactMap(RestrictiveDietID.init(rawValue:)),
            fastingWindow: fastingWindowRaw.flatMap(FastingWindow.init(rawValue:))
        )
    }

    func toggling(_ id: RestrictiveDietID) -> NutritionDietSelection {
        if id == .none {
            if dietIDs == [.none] { return .unanswered }
            return NutritionDietSelection(dietIDs: [.none], fastingWindow: nil)
        }
        var ids = dietIDs.filter { $0 != .none }
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        } else {
            ids.append(id)
        }
        let window = ids.contains(.intermittentFasting) ? (fastingWindow ?? .sixteenEight) : nil
        return NutritionDietSelection(dietIDs: ids, fastingWindow: window)
    }

    func selectingFastingWindow(_ window: FastingWindow) -> NutritionDietSelection {
        NutritionDietSelection(dietIDs: dietIDs, fastingWindow: window)
    }
}

struct WorkoutFuelSeed: Equatable {
    var foods: String
    var timing: String
}

fileprivate struct FastingFuelPair: Equatable {
    var preWorkout: WorkoutFuelSeed
    var postWorkout: WorkoutFuelSeed
}

/// One locked diet plus the product-seeded pre/post workout fuel ideas.
struct RestrictiveDiet: Identifiable, Equatable {
    var id: RestrictiveDietID
    var summary: String
    var preWorkout: WorkoutFuelSeed
    var postWorkout: WorkoutFuelSeed
    fileprivate var fasting: [FastingWindow: FastingFuelPair]

    var displayName: String { id.displayName }

    func fuel(window: FastingWindow?) -> (pre: WorkoutFuelSeed, post: WorkoutFuelSeed) {
        if id == .intermittentFasting, let window, let pair = fasting[window] {
            return (pair.preWorkout, pair.postWorkout)
        }
        return (preWorkout, postWorkout)
    }
}

/// Local catalog. Copy is a product-seeded default for training fuel, not a prescription.
enum RestrictiveDietCatalog {
    static func diet(id: RestrictiveDietID) -> RestrictiveDiet? { byID[id] }

    static var choices: [RestrictiveDiet] {
        RestrictiveDietID.allCases.compactMap { byID[$0] }
    }

    static func ordered(_ ids: [RestrictiveDietID]) -> [RestrictiveDietID] {
        let selected = Set(ids)
        return RestrictiveDietID.allCases.filter { selected.contains($0) }
    }

    private static let byID: [RestrictiveDietID: RestrictiveDiet] = Dictionary(
        uniqueKeysWithValues: entries.map { ($0.id, $0) }
    )

    static let entries: [RestrictiveDiet] = [
        entry(
            .none,
            summary: "No restrictive pattern from this list.",
            pre: "Banana or toast with a little protein",
            preTiming: "45–60 min before",
            post: "A normal meal with protein and carbs",
            postTiming: "Within 60 min"
        ),
        entry(
            .danielFast,
            summary: "Plants and water. Skips meat, dairy, sweeteners, and alcohol.",
            pre: "Banana and a handful of almonds",
            preTiming: "45–60 min before",
            post: "Lentils, rice, and vegetables",
            postTiming: "Within 60 min"
        ),
        entry(
            .keto,
            summary: "Meat, eggs, low-carb vegetables, and fat. Skips grains, sugar, and most fruit.",
            pre: "Eggs and avocado",
            preTiming: "60–90 min before",
            post: "Salmon or chicken with leafy greens and olive oil",
            postTiming: "Within 60 min"
        ),
        entry(
            .carnivore,
            summary: "Meat, fish, and eggs. Skips plants.",
            pre: "A few eggs or beef jerky",
            preTiming: "60–90 min before",
            post: "Steak or ground beef",
            postTiming: "Within 60 min"
        ),
        entry(
            .vegan,
            summary: "Plants only. Skips meat, dairy, eggs, and honey.",
            pre: "Banana and peanut butter",
            preTiming: "45–60 min before",
            post: "Lentils and chickpeas with rice",
            postTiming: "Within 60 min"
        ),
        entry(
            .vegetarian,
            summary: "Plants, dairy, and eggs. Skips meat and fish.",
            pre: "Greek yogurt and a banana",
            preTiming: "45–60 min before",
            post: "Eggs or cottage cheese with fruit",
            postTiming: "Within 60 min"
        ),
        entry(
            .drSebi,
            summary: "Greens, fruit, and approved grains. Skips meat, dairy, and most processed food.",
            pre: "Berries or watermelon",
            preTiming: "45–60 min before",
            post: "Quinoa or spelt with greens and avocado",
            postTiming: "Within 90 min"
        ),
        entry(
            .mediterranean,
            summary: "Fish, olive oil, vegetables, whole grains, and legumes. Skips most ultra-processed food.",
            pre: "Fruit and a few nuts",
            preTiming: "45–60 min before",
            post: "Fish, vegetables, olive oil, and a whole grain",
            postTiming: "Within 60 min"
        ),
        entry(
            .paleo,
            summary: "Meat, fish, eggs, vegetables, fruit, and nuts. Skips grains, dairy, and legumes.",
            pre: "Banana and almond butter",
            preTiming: "45–60 min before",
            post: "Chicken or fish with sweet potato and vegetables",
            postTiming: "Within 60 min"
        ),
        entry(
            .whole30,
            summary: "Meat, seafood, eggs, vegetables, and fruit. Skips sugar, grains, dairy, legumes, and alcohol.",
            pre: "Apple and a handful of nuts",
            preTiming: "45–60 min before",
            post: "Eggs or meat with potatoes and vegetables",
            postTiming: "Within 60 min"
        ),
        entry(
            .pescatarian,
            summary: "Fish, seafood, and plants. Skips land meat.",
            pre: "Banana and yogurt, or fruit if you skip dairy",
            preTiming: "45–60 min before",
            post: "Salmon or tuna with rice and vegetables",
            postTiming: "Within 60 min"
        ),
        entry(
            .flexitarian,
            summary: "Mostly plants, with some meat. Nothing is fully off the list.",
            pre: "Fruit with yogurt, or a small turkey wrap",
            preTiming: "45–60 min before",
            post: "Chickpeas or a modest portion of chicken, with grains and vegetables",
            postTiming: "Within 60 min"
        ),
        RestrictiveDiet(
            id: .intermittentFasting,
            summary: "Eat inside a set window. Skip calories outside it.",
            preWorkout: WorkoutFuelSeed(
                foods: "If you train inside the 16:8 window, fruit or toast. If you train fasted, water only.",
                timing: "16:8 — 30–60 min before, or stay fasted until the window opens"
            ),
            postWorkout: WorkoutFuelSeed(
                foods: "Protein and carbs inside the 16:8 eating window",
                timing: "16:8 — within 60 min if the window is open; otherwise the first meal when it opens"
            ),
            fasting: [
                .sixteenEight: FastingFuelPair(
                    preWorkout: WorkoutFuelSeed(
                        foods: "If you train inside the 16:8 window, fruit or toast. If you train fasted, water only.",
                        timing: "16:8 — 30–60 min before, or stay fasted until the window opens"
                    ),
                    postWorkout: WorkoutFuelSeed(
                        foods: "Protein and carbs inside the 16:8 eating window",
                        timing: "16:8 — within 60 min if the window is open; otherwise the first meal when it opens"
                    )
                ),
                .omad: FastingFuelPair(
                    preWorkout: WorkoutFuelSeed(
                        foods: "Water. Save the OMAD meal for after training.",
                        timing: "OMAD — train close to the one meal"
                    ),
                    postWorkout: WorkoutFuelSeed(
                        foods: "The OMAD meal, with protein and carbs",
                        timing: "OMAD — right after training"
                    )
                ),
            ]
        ),
        entry(
            .highProtein,
            summary: "Extra protein at meals. Nothing else is required off the plate.",
            pre: "Greek yogurt or a shake",
            preTiming: "45–75 min before",
            post: "Chicken, eggs, tofu, or a shake, plus some carbs",
            postTiming: "Within 60 min"
        ),
        entry(
            .lowCarb,
            summary: "Meat, fish, eggs, vegetables, and some fruit. Skips sugary drinks and large grain servings. Not full keto.",
            pre: "Eggs or Greek yogurt with berries",
            preTiming: "60–90 min before",
            post: "Chicken or fish with vegetables and a small potato",
            postTiming: "Within 60 min"
        ),
    ]

    private static func entry(
        _ id: RestrictiveDietID,
        summary: String,
        pre: String,
        preTiming: String,
        post: String,
        postTiming: String
    ) -> RestrictiveDiet {
        RestrictiveDiet(
            id: id,
            summary: summary,
            preWorkout: WorkoutFuelSeed(foods: pre, timing: preTiming),
            postWorkout: WorkoutFuelSeed(foods: post, timing: postTiming),
            fasting: [:]
        )
    }
}

struct DietFuelCard: Equatable, Identifiable {
    var id: RestrictiveDietID
    var displayName: String
    var summary: String
    var preWorkoutFoods: String
    var preWorkoutTiming: String
    var postWorkoutFoods: String
    var postWorkoutTiming: String
}

/// What the Nutrition section renders for the current answer.
struct DietFuelSurface: Equatable {
    var disclaimer: String
    var overlapNote: String?
    var cards: [DietFuelCard]

    var isVisible: Bool { !cards.isEmpty }
}

enum DietWorkoutFueling {
    static let disclaimer = "Product-seeded fueling ideas, not medical advice."

    static func surface(for selection: NutritionDietSelection) -> DietFuelSurface {
        let cards = selection.dietIDs.compactMap { id -> DietFuelCard? in
            guard let diet = RestrictiveDietCatalog.diet(id: id) else { return nil }
            let fuel = diet.fuel(window: selection.fastingWindow)
            return DietFuelCard(
                id: id,
                displayName: diet.displayName,
                summary: diet.summary,
                preWorkoutFoods: fuel.pre.foods,
                preWorkoutTiming: fuel.pre.timing,
                postWorkoutFoods: fuel.post.foods,
                postWorkoutTiming: fuel.post.timing
            )
        }
        let overlap = cards.count > 1
            ? "Each diet is listed on its own. Where they disagree, pick the option that fits both."
            : nil
        return DietFuelSurface(disclaimer: disclaimer, overlapNote: overlap, cards: cards)
    }
}

/// The Nutrition "Are you on any restrictive diets?" block, without SwiftUI.
struct RestrictiveDietSectionState: Equatable {
    var selection: NutritionDietSelection
    var surface: DietFuelSurface
    var showsFastingWindows: Bool

    static func make(_ selection: NutritionDietSelection) -> RestrictiveDietSectionState {
        RestrictiveDietSectionState(
            selection: selection,
            surface: DietWorkoutFueling.surface(for: selection),
            showsFastingWindows: selection.dietIDs.contains(.intermittentFasting)
        )
    }
}
