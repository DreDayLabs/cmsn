import Foundation

/// One food-diary row reduced to the fields the remainder math needs.
/// Calories stay optional because quick-adds (a shake, a meal shortcut)
/// never recorded them — treating a missing calorie count as zero would
/// silently pretend that food had no energy.
struct LoggedFoodContribution: Equatable {
    var proteinGrams: Double
    var calories: Double?
}

/// Protein and calories still open today: the day's targets minus what's
/// in today's food diary.
///
/// Remaining values are signed. Negative means the diary is already past
/// that target. Zero means the diary landed on it. An empty diary leaves
/// the full targets in place.
///
/// This type only subtracts. It does not estimate a workout. On a training
/// day, pass targets from `TrainingDayAdjustment` (non-exercise baseline
/// plus 2024 Compendium net session energy). On a rest day, pass that
/// same baseline. The weekly activity bands in `MacroTargetCalculator`
/// already spread training across every day, so they are not added again
/// here.
struct RemainingMacros: Equatable {
    var proteinTargetGrams: Double
    var calorieTarget: Double
    var proteinLoggedGrams: Double
    var caloriesLogged: Double
    var entryCount: Int
    /// Diary rows that recorded food but no calories. They still count
    /// toward protein. The calorie remainder only subtracts known calories,
    /// so it can overstate calories left while this is non-zero.
    var entriesMissingCalories: Int

    var proteinRemainingGrams: Double { proteinTargetGrams - proteinLoggedGrams }
    var caloriesRemaining: Double { calorieTarget - caloriesLogged }
    var hasLoggedFood: Bool { entryCount > 0 }
    var isOverProteinTarget: Bool { proteinRemainingGrams < 0 }
    var isOverCalorieTarget: Bool { caloriesRemaining < 0 }

    static func calculate(targets: MacroTargets, entries: [LoggedFoodContribution]) -> RemainingMacros {
        RemainingMacros(
            proteinTargetGrams: targets.proteinGrams,
            calorieTarget: targets.calorieEstimate,
            proteinLoggedGrams: entries.reduce(0) { $0 + $1.proteinGrams },
            caloriesLogged: entries.reduce(0) { $0 + ($1.calories ?? 0) },
            entryCount: entries.count,
            entriesMissingCalories: entries.filter { $0.calories == nil }.count
        )
    }

    static func calculate(targets: MacroTargets, entries: [NutritionEntry]) -> RemainingMacros {
        calculate(
            targets: targets,
            entries: entries.map {
                LoggedFoodContribution(proteinGrams: $0.proteinGrams, calories: $0.calories)
            }
        )
    }
}
