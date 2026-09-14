import Foundation

/// The V0 static content: exercise catalog, seed programs, and seed meals.
/// Authored residential-gym-first per the equipment strategy — a Smith
/// machine, dumbbells, kettlebells, cables, bands, and a couple of machines
/// cover every seeded exercise, because that's what the product doc
/// identifies as the most common real-world gym this audience actually has
/// (a premium residential building, not a full-service gym).
enum SeedData {
    // MARK: - Exercise catalog

    static let exercises: [Exercise] = [
        // Push
        Exercise(
            id: "smith-bench-press",
            name: "Smith Machine Bench Press",
            primaryMuscleGroups: [.chest, .triceps, .shoulders],
            equipmentRequired: [.smithMachine, .bench],
            formCues: ["Feet flat, shoulder blades pulled together and down.", "Bar path is straight down to mid-chest, not toward your neck."],
            commonMistake: "Flaring elbows out to 90°, which stresses the shoulder joint — keep them closer to a 45° angle.",
            setupInstructions: "Bench centered under the bar, bar starts directly over your eyes.",
            whyThisExercise: "The Smith machine's fixed bar path makes this a safe, repeatable way to load the chest without needing a spotter.",
            easierAlternativeExerciseID: "pushup",
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.chest, .shoulder, .elbow],
            trackingType: .repsAndWeight
        ),
        Exercise(
            id: "db-shoulder-press",
            name: "Dumbbell Shoulder Press",
            primaryMuscleGroups: [.shoulders, .triceps],
            equipmentRequired: [.dumbbells, .bench],
            formCues: ["Press straight overhead, not forward.", "Keep ribs down — don't overarch your lower back."],
            commonMistake: "Letting the dumbbells drift forward of your ears at the top, which loads the lower back instead of the shoulders.",
            setupInstructions: "Seated or standing, dumbbells at shoulder height, palms forward.",
            whyThisExercise: "Builds shoulder strength and stability with a full, natural range of motion.",
            easierAlternativeExerciseID: "band-shoulder-press",
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.shoulder, .elbow, .lowerBack],
            trackingType: .repsAndWeight
        ),
        Exercise(
            id: "cable-chest-fly",
            name: "Cable Chest Fly",
            primaryMuscleGroups: [.chest],
            equipmentRequired: [.cable],
            formCues: ["Slight bend in the elbow held constant through the motion.", "Squeeze at the center, don't let the cables snap back."],
            commonMistake: "Turning it into a press by bending the elbows more as the weight gets heavy.",
            setupInstructions: "Cables set to chest height, split stance for stability.",
            whyThisExercise: "Isolates the chest with constant tension the whole rep, which a barbell press doesn't give you.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.chest, .shoulder],
            trackingType: .repsAndWeight
        ),
        Exercise(
            id: "db-incline-press",
            name: "Dumbbell Incline Press",
            primaryMuscleGroups: [.chest, .shoulders, .triceps],
            equipmentRequired: [.dumbbells, .bench],
            formCues: ["Bench at 30–45°, not steeper.", "Drive dumbbells up and slightly in."],
            commonMistake: "Setting the incline too steep, which turns it into a shoulder press.",
            setupInstructions: "Bench at 30–45°, dumbbells at shoulder height.",
            whyThisExercise: "Targets the upper chest, which a flat press under-trains.",
            easierAlternativeExerciseID: "pushup",
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.chest, .shoulder, .elbow],
            trackingType: .repsAndWeight
        ),
        Exercise(
            id: "cable-triceps-pushdown",
            name: "Cable Triceps Pushdown",
            primaryMuscleGroups: [.triceps],
            equipmentRequired: [.cable],
            formCues: ["Elbows pinned to your sides the whole set.", "Full extension at the bottom without locking out hard."],
            commonMistake: "Letting the elbows drift forward, which turns it into a chest movement.",
            setupInstructions: "Cable at chest height, rope or straight bar attachment.",
            whyThisExercise: "Direct triceps isolation to finish a push day.",
            easierAlternativeExerciseID: "band-triceps-pushdown",
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.elbow], // triceps aren't a BodyArea in this model — elbow is the joint of record
            trackingType: .repsAndWeight
        ),
        Exercise(
            id: "pushup",
            name: "Push-Up",
            primaryMuscleGroups: [.chest, .triceps, .shoulders],
            equipmentRequired: [.bodyweight],
            formCues: ["Straight line from head to heels.", "Full range — chest close to the floor."],
            commonMistake: "Letting the hips sag, which loads the lower back.",
            setupInstructions: "Hands slightly wider than shoulders, on the floor or an elevated surface to start easier.",
            whyThisExercise: "No-equipment fallback that still trains the same movement pattern as a bench press.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: "smith-bench-press",
            loadedBodyAreas: [.chest, .shoulder, .wrist],
            trackingType: .repsOnly
        ),
        Exercise(
            id: "band-shoulder-press",
            name: "Band Shoulder Press",
            primaryMuscleGroups: [.shoulders, .triceps],
            equipmentRequired: [.band],
            formCues: ["Stand on the band, press straight overhead.", "Keep your core braced so your back doesn't arch."],
            commonMistake: "Using momentum from the legs instead of pressing with the shoulders.",
            setupInstructions: "Band anchored under both feet, one handle in each hand at shoulder height.",
            whyThisExercise: "A travel/home-friendly substitute that still trains overhead pressing.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: "db-shoulder-press",
            loadedBodyAreas: [.shoulder, .elbow],
            trackingType: .repsOnly
        ),
        Exercise(
            id: "band-triceps-pushdown",
            name: "Band Triceps Pushdown",
            primaryMuscleGroups: [.triceps],
            equipmentRequired: [.band],
            formCues: ["Elbows pinned to your sides.", "Control the return — don't let the band snap your arm back up."],
            commonMistake: "Using a band anchor too low, losing tension at the top of the rep.",
            setupInstructions: "Band anchored high (a door anchor or high point), same motion as a cable pushdown.",
            whyThisExercise: "Travel/home substitute for cable triceps work.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: "cable-triceps-pushdown",
            loadedBodyAreas: [.elbow],
            trackingType: .repsOnly
        ),

        // Pull
        Exercise(
            id: "lat-pulldown",
            name: "Lat Pulldown",
            primaryMuscleGroups: [.back, .biceps],
            equipmentRequired: [.machine, .cable],
            formCues: ["Pull to your upper chest, not behind your neck.", "Lead with your elbows, not your hands."],
            commonMistake: "Leaning back excessively and turning it into a rowing motion.",
            setupInstructions: "Thighs secured under the pad, wide overhand grip.",
            whyThisExercise: "The most accessible way to train the vertical pulling pattern without a pull-up bar.",
            easierAlternativeExerciseID: "band-pulldown",
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.shoulder, .elbow, .upperBack],
            trackingType: .repsAndWeight
        ),
        Exercise(
            id: "db-row",
            name: "Dumbbell Row",
            primaryMuscleGroups: [.back, .biceps],
            equipmentRequired: [.dumbbells, .bench],
            formCues: ["Pull the elbow back and up, not just up.", "Keep your back flat, not rounded."],
            commonMistake: "Twisting the torso to help lift the weight instead of using the back.",
            setupInstructions: "One knee and hand on a bench, opposite foot planted, dumbbell hanging straight down.",
            whyThisExercise: "Unilateral back work that also challenges core stability.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.upperBack, .lowerBack, .shoulder],
            trackingType: .repsAndWeight,
            isUnilateral: true
        ),
        Exercise(
            id: "seated-cable-row",
            name: "Seated Cable Row",
            primaryMuscleGroups: [.back, .biceps],
            equipmentRequired: [.cable, .machine],
            formCues: ["Chest up, pull to your lower ribs.", "Don't lean back to finish the pull — that's your lower back, not your lats."],
            commonMistake: "Using body momentum (rocking back and forth) instead of controlled pulling.",
            setupInstructions: "Feet on the platform, slight knee bend, neutral-grip handle.",
            whyThisExercise: "Horizontal pulling pattern that balances out pressing work.",
            easierAlternativeExerciseID: "band-row",
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.upperBack, .lowerBack],
            trackingType: .repsAndWeight
        ),
        Exercise(
            id: "db-bicep-curl",
            name: "Dumbbell Bicep Curl",
            primaryMuscleGroups: [.biceps],
            equipmentRequired: [.dumbbells],
            formCues: ["Elbows stay close to your torso.", "Control the lowering phase — don't just drop the weight."],
            commonMistake: "Swinging the torso to generate momentum instead of isolating the biceps.",
            setupInstructions: "Standing, dumbbells at your sides, palms forward.",
            whyThisExercise: "Direct biceps work to round out a pull day.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.elbow],
            trackingType: .repsAndWeight
        ),
        Exercise(
            id: "cable-face-pull",
            name: "Cable Face Pull",
            primaryMuscleGroups: [.shoulders, .back],
            equipmentRequired: [.cable],
            formCues: ["Pull toward your face, elbows high.", "Squeeze your shoulder blades together at the end."],
            commonMistake: "Pulling too low, which turns it into a row instead of a face pull.",
            setupInstructions: "Rope attachment set at upper-chest to face height.",
            whyThisExercise: "Trains the rear shoulders and upper back — a common weak point that pressing-heavy programs miss.",
            easierAlternativeExerciseID: "band-face-pull",
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.shoulder, .neck],
            trackingType: .repsAndWeight
        ),
        Exercise(
            id: "band-pulldown",
            name: "Band Lat Pulldown",
            primaryMuscleGroups: [.back, .biceps],
            equipmentRequired: [.band],
            formCues: ["Anchor the band high, pull to your upper chest.", "Keep your ribs down, don't arch to finish the pull."],
            commonMistake: "Using a low anchor point, which removes the lat-focused pulling angle.",
            setupInstructions: "Band anchored high (door anchor), kneeling or seated.",
            whyThisExercise: "Travel/home substitute for lat pulldown.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: "lat-pulldown",
            loadedBodyAreas: [.shoulder, .upperBack],
            trackingType: .repsOnly
        ),
        Exercise(
            id: "band-row",
            name: "Band Row",
            primaryMuscleGroups: [.back, .biceps],
            equipmentRequired: [.band],
            formCues: ["Pull elbows straight back, squeeze shoulder blades.", "Keep your chest up the whole rep."],
            commonMistake: "Rounding the upper back to finish the pull.",
            setupInstructions: "Band anchored at chest height in front of you, or looped around a sturdy post.",
            whyThisExercise: "Travel/home substitute for cable/machine rowing.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: "seated-cable-row",
            loadedBodyAreas: [.upperBack],
            trackingType: .repsOnly
        ),
        Exercise(
            id: "band-face-pull",
            name: "Band Face Pull",
            primaryMuscleGroups: [.shoulders, .back],
            equipmentRequired: [.band],
            formCues: ["Pull toward your face, elbows high and wide.", "Pause and squeeze at the end range."],
            commonMistake: "Using too light a band and rushing the rep instead of controlling it.",
            setupInstructions: "Band anchored at face height.",
            whyThisExercise: "Travel/home substitute for cable face pulls.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: "cable-face-pull",
            loadedBodyAreas: [.shoulder, .neck],
            trackingType: .repsOnly
        ),

        // Legs
        Exercise(
            id: "smith-squat",
            name: "Smith Machine Squat",
            primaryMuscleGroups: [.quadriceps, .glutes, .hamstrings],
            equipmentRequired: [.smithMachine],
            formCues: ["Feet slightly forward of the bar path for a natural squat angle.", "Knees track over your toes, don't cave in."],
            commonMistake: "Feet placed directly under the bar, which forces an unnatural forward lean.",
            setupInstructions: "Bar on your upper back, feet shoulder-width, slightly forward of the bar.",
            whyThisExercise: "The Smith machine's guided path makes squatting safer without a spotter — a real strength-training option even in a residential gym.",
            easierAlternativeExerciseID: "kb-goblet-squat",
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.knee, .hip, .lowerBack],
            trackingType: .repsAndWeight
        ),
        Exercise(
            id: "db-romanian-deadlift",
            name: "Dumbbell Romanian Deadlift",
            primaryMuscleGroups: [.hamstrings, .glutes],
            equipmentRequired: [.dumbbells],
            formCues: ["Hinge at the hips, keep the dumbbells close to your legs.", "Keep a slight bend in the knees the whole rep."],
            commonMistake: "Rounding the lower back instead of hinging with a flat back.",
            setupInstructions: "Standing, dumbbells in front of your thighs.",
            whyThisExercise: "Trains the hip hinge and hamstrings — the movement pattern most leg days under-train.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.lowerBack, .hamstring, .hip],
            trackingType: .repsAndWeight
        ),
        Exercise(
            id: "leg-press",
            name: "Leg Press",
            primaryMuscleGroups: [.quadriceps, .glutes],
            equipmentRequired: [.machine],
            formCues: ["Feet shoulder-width on the platform.", "Don't let your lower back round off the pad at the bottom."],
            commonMistake: "Going so deep that the lower back lifts off the pad.",
            setupInstructions: "Seated, feet on the platform, back flat against the pad.",
            whyThisExercise: "Loads the legs heavily with less lower-back demand than a squat.",
            easierAlternativeExerciseID: "kb-goblet-squat",
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.knee, .lowerBack],
            trackingType: .repsAndWeight
        ),
        Exercise(
            id: "db-walking-lunge",
            name: "Dumbbell Walking Lunge",
            primaryMuscleGroups: [.quadriceps, .glutes, .hamstrings],
            equipmentRequired: [.dumbbells],
            formCues: ["Step far enough that your front knee stays over your ankle.", "Keep your torso upright."],
            commonMistake: "Taking too short a step, which drives the front knee past the toes.",
            setupInstructions: "Dumbbells at your sides, open floor space to walk forward.",
            whyThisExercise: "Unilateral leg work that also trains balance.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.knee, .hip],
            trackingType: .repsAndWeight,
            isUnilateral: true
        ),
        Exercise(
            id: "leg-curl",
            name: "Leg Curl Machine",
            primaryMuscleGroups: [.hamstrings],
            equipmentRequired: [.machine],
            formCues: ["Control the negative — don't let the weight snap back.", "Keep your hips pressed into the pad."],
            commonMistake: "Lifting the hips off the pad to curl more weight.",
            setupInstructions: "Lying or seated per the machine, pad positioned just above the heel.",
            whyThisExercise: "Direct hamstring isolation.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.hamstring, .knee],
            trackingType: .repsAndWeight
        ),
        Exercise(
            id: "calf-raise",
            name: "Standing Calf Raise",
            primaryMuscleGroups: [.calves],
            equipmentRequired: [.machine, .dumbbells],
            formCues: ["Full range — stretch at the bottom, full squeeze at the top.", "Pause briefly at the top of each rep."],
            commonMistake: "Bouncing through a partial range instead of controlling the full motion.",
            setupInstructions: "Balls of your feet on a raised platform, holding dumbbells or on a machine.",
            whyThisExercise: "Calves respond well to focused, controlled volume — easy to under-train otherwise.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.calf, .ankle],
            trackingType: .repsAndWeight
        ),

        // Core
        Exercise(
            id: "plank",
            name: "Plank",
            primaryMuscleGroups: [.core],
            equipmentRequired: [.bodyweight],
            formCues: ["Straight line from shoulders to heels.", "Squeeze your glutes and brace like you're about to be poked in the stomach."],
            commonMistake: "Letting the hips sag or pike up.",
            setupInstructions: "Forearms and toes on the floor.",
            whyThisExercise: "Core stability work that supports every other lift.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.lowerBack, .shoulder],
            trackingType: .time
        ),
        Exercise(
            id: "cable-woodchopper",
            name: "Cable Woodchopper",
            primaryMuscleGroups: [.core],
            equipmentRequired: [.cable],
            formCues: ["Rotate from your torso, not just your arms.", "Keep a slight knee bend and pivot your back foot."],
            commonMistake: "Using the arms to move the weight instead of rotating through the core.",
            setupInstructions: "Cable set high or low depending on the variation, standing side-on.",
            whyThisExercise: "Trains rotational core strength, which straight-ahead crunches don't touch.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.lowerBack],
            trackingType: .repsAndWeight,
            isUnilateral: true
        ),
        Exercise(
            id: "hanging-knee-raise",
            name: "Hanging Knee Raise",
            primaryMuscleGroups: [.core],
            equipmentRequired: [.machine, .bodyweight],
            formCues: ["Curl your pelvis up, don't just swing your legs.", "Control the lowering phase."],
            commonMistake: "Using momentum/swinging instead of controlled core contraction.",
            setupInstructions: "Hanging from a bar or in an assisted captain's-chair machine.",
            whyThisExercise: "Trains the lower abs through a real range of motion.",
            easierAlternativeExerciseID: "plank",
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.lowerBack, .shoulder, .hip],
            trackingType: .repsOnly
        ),

        // Kettlebell
        Exercise(
            id: "kb-swing",
            name: "Kettlebell Swing",
            primaryMuscleGroups: [.glutes, .hamstrings, .core],
            equipmentRequired: [.kettlebell],
            formCues: ["Hinge at the hips — this is a hip snap, not a squat.", "Let the kettlebell float, don't lift it with your arms."],
            commonMistake: "Squatting the swing instead of hinging, which turns it into a front raise with the legs doing nothing.",
            setupInstructions: "Kettlebell on the floor in front of you, feet shoulder-width.",
            whyThisExercise: "A full-body, conditioning-and-strength hybrid that's fast to load and fits small spaces.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.lowerBack, .hip, .shoulder],
            trackingType: .repsOnly
        ),
        Exercise(
            id: "kb-goblet-squat",
            name: "Kettlebell Goblet Squat",
            primaryMuscleGroups: [.quadriceps, .glutes],
            equipmentRequired: [.kettlebell],
            formCues: ["Hold the bell at your chest, elbows pointed down.", "Sit back and down, keep your chest tall."],
            commonMistake: "Letting the chest fall forward as the squat gets deep.",
            setupInstructions: "Kettlebell held vertically against your chest by the horns.",
            whyThisExercise: "An accessible squat pattern that's easy on the lower back — a natural easier alternative to a barbell/Smith squat.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: "smith-squat",
            loadedBodyAreas: [.knee, .hip],
            trackingType: .repsAndWeight
        ),
        Exercise(
            id: "kb-clean-and-press",
            name: "Kettlebell Clean and Press",
            primaryMuscleGroups: [.fullBody, .shoulders],
            equipmentRequired: [.kettlebell],
            formCues: ["Keep the bell close on the clean — don't loop it out and around.", "Press with control, don't lean back to finish."],
            commonMistake: "Banging the bell into the wrist/forearm on the clean instead of 'catching' it softly.",
            setupInstructions: "Kettlebell on the floor between your feet.",
            whyThisExercise: "A full-body power-and-strength movement in one motion — efficient for time-limited sessions.",
            easierAlternativeExerciseID: "kb-swing",
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.wrist, .shoulder, .lowerBack],
            trackingType: .repsAndWeight,
            isUnilateral: true
        ),
        Exercise(
            id: "kb-halo",
            name: "Kettlebell Halo",
            primaryMuscleGroups: [.shoulders, .core],
            equipmentRequired: [.kettlebell],
            formCues: ["Circle the bell slowly around your head, close to your body.", "Keep your ribs down, don't arch to let the bell pass behind your head."],
            commonMistake: "Circling too far from the head, turning it into an uncontrolled swing.",
            setupInstructions: "Kettlebell held upside-down by the horns at chest/chin height.",
            whyThisExercise: "A light mobility-and-stability movement that works well as a warm-up or finisher.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.shoulder, .neck],
            trackingType: .repsOnly
        ),

        // Cardio / mobility
        Exercise(
            id: "treadmill-intervals",
            name: "Treadmill Intervals",
            primaryMuscleGroups: [.cardio],
            equipmentRequired: [.cardioMachine],
            formCues: ["Land under your hips, not out in front.", "Keep your torso tall, don't hunch over the console."],
            commonMistake: "Holding the handrails, which reduces the workout and encourages poor posture.",
            setupInstructions: "Alternating higher-effort and recovery intervals per your program.",
            whyThisExercise: "Efficient conditioning that fits in a residential-gym cardio bay.",
            easierAlternativeExerciseID: "walking-session",
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.knee, .shin, .foot],
            trackingType: .time
        ),
        Exercise(
            id: "walking-session",
            name: "Walking Session",
            primaryMuscleGroups: [.cardio],
            equipmentRequired: [.cardioMachine, .bodyweight],
            formCues: ["Comfortable, sustainable pace.", "Arms relaxed and swinging naturally."],
            commonMistake: "Overstriding, which can strain the hip flexors and lower back.",
            setupInstructions: "Treadmill, outdoors, or any flat walking route.",
            whyThisExercise: "The lowest-barrier cardio and recovery-day option — always available, always appropriate.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: "treadmill-intervals",
            loadedBodyAreas: [],
            trackingType: .distance
        ),
        Exercise(
            id: "hip-flexor-stretch",
            name: "Hip Flexor Stretch",
            primaryMuscleGroups: [.core],
            equipmentRequired: [.bodyweight],
            formCues: ["Squeeze the glute on the back leg to deepen the stretch.", "Keep your torso upright, don't lean forward."],
            commonMistake: "Arching the lower back instead of tucking the pelvis to isolate the stretch.",
            setupInstructions: "Half-kneeling position, back knee on the floor.",
            whyThisExercise: "Counteracts hours of sitting and supports hip mobility for squats and lunges.",
            easierAlternativeExerciseID: nil,
            advancedAlternativeExerciseID: nil,
            loadedBodyAreas: [.hip, .lowerBack],
            trackingType: .time
        ),
    ]

    // MARK: - Programs

    static let pushPullLegs = TrainingProgram(
        id: "push-pull-legs",
        name: "Push / Pull / Legs",
        days: [
            ProgramDay(focus: .push, plannedExercises: [
                PlannedExercise(exerciseID: "smith-bench-press", plannedSets: threeWorkingSets(8, 12), orderIndex: 0),
                PlannedExercise(exerciseID: "db-incline-press", plannedSets: threeWorkingSets(8, 12), orderIndex: 1),
                PlannedExercise(exerciseID: "db-shoulder-press", plannedSets: threeWorkingSets(8, 12), orderIndex: 2),
                PlannedExercise(exerciseID: "cable-triceps-pushdown", plannedSets: threeWorkingSets(10, 15), orderIndex: 3),
            ], authoredForEquipmentProfile: .residentialGym),
            ProgramDay(focus: .pull, plannedExercises: [
                PlannedExercise(exerciseID: "lat-pulldown", plannedSets: threeWorkingSets(8, 12), orderIndex: 0),
                PlannedExercise(exerciseID: "seated-cable-row", plannedSets: threeWorkingSets(8, 12), orderIndex: 1),
                PlannedExercise(exerciseID: "db-row", plannedSets: threeWorkingSets(8, 12), orderIndex: 2),
                PlannedExercise(exerciseID: "cable-face-pull", plannedSets: threeWorkingSets(12, 15), orderIndex: 3),
                PlannedExercise(exerciseID: "db-bicep-curl", plannedSets: threeWorkingSets(10, 15), orderIndex: 4),
            ], authoredForEquipmentProfile: .residentialGym),
            ProgramDay(focus: .legs, plannedExercises: [
                PlannedExercise(exerciseID: "smith-squat", plannedSets: threeWorkingSets(6, 10), orderIndex: 0),
                PlannedExercise(exerciseID: "db-romanian-deadlift", plannedSets: threeWorkingSets(8, 12), orderIndex: 1),
                PlannedExercise(exerciseID: "leg-press", plannedSets: threeWorkingSets(10, 15), orderIndex: 2),
                PlannedExercise(exerciseID: "leg-curl", plannedSets: threeWorkingSets(10, 15), orderIndex: 3),
                PlannedExercise(exerciseID: "calf-raise", plannedSets: threeWorkingSets(12, 20), orderIndex: 4),
            ], authoredForEquipmentProfile: .residentialGym),
        ]
    )

    static let upperLower = TrainingProgram(
        id: "upper-lower",
        name: "Upper / Lower",
        days: [
            ProgramDay(focus: .upperBody, plannedExercises: [
                PlannedExercise(exerciseID: "smith-bench-press", plannedSets: threeWorkingSets(8, 12), orderIndex: 0),
                PlannedExercise(exerciseID: "lat-pulldown", plannedSets: threeWorkingSets(8, 12), orderIndex: 1),
                PlannedExercise(exerciseID: "db-shoulder-press", plannedSets: threeWorkingSets(8, 12), orderIndex: 2),
                PlannedExercise(exerciseID: "db-row", plannedSets: threeWorkingSets(8, 12), orderIndex: 3),
                PlannedExercise(exerciseID: "db-bicep-curl", plannedSets: threeWorkingSets(10, 15), orderIndex: 4),
                PlannedExercise(exerciseID: "cable-triceps-pushdown", plannedSets: threeWorkingSets(10, 15), orderIndex: 5),
            ], authoredForEquipmentProfile: .residentialGym),
            ProgramDay(focus: .lowerBody, plannedExercises: [
                PlannedExercise(exerciseID: "smith-squat", plannedSets: threeWorkingSets(6, 10), orderIndex: 0),
                PlannedExercise(exerciseID: "db-romanian-deadlift", plannedSets: threeWorkingSets(8, 12), orderIndex: 1),
                PlannedExercise(exerciseID: "db-walking-lunge", plannedSets: threeWorkingSets(10, 12), orderIndex: 2),
                PlannedExercise(exerciseID: "leg-curl", plannedSets: threeWorkingSets(10, 15), orderIndex: 3),
                PlannedExercise(exerciseID: "plank", plannedSets: threeWorkingSets(30, 60), orderIndex: 4),
            ], authoredForEquipmentProfile: .residentialGym),
        ]
    )

    static let allPrograms: [TrainingProgram] = [pushPullLegs, upperLower]

    private static func threeWorkingSets(_ low: Int, _ high: Int) -> [PlannedSet] {
        (0..<3).map { _ in PlannedSet(setType: .working, targetRepRangeLow: low, targetRepRangeHigh: high, targetWeightKG: nil) }
    }

    /// Muscle groups implied by a split focus — used by `ProgramResolver`
    /// when building an ad-hoc day for a calendar override or quick-path
    /// session that has no explicit `ProgramDay` entry.
    static func muscleGroups(for focus: SplitFocus) -> [MuscleGroup] {
        switch focus {
        case .push, .chest: return [.chest, .shoulders, .triceps]
        case .pull, .back, .arms: return [.back, .biceps, .shoulders, .triceps]
        case .legs, .lowerBody: return [.quadriceps, .hamstrings, .glutes, .calves]
        case .upperBody: return [.chest, .back, .shoulders, .biceps, .triceps]
        case .core: return [.core]
        case .fullBody, .kettlebell: return [.fullBody, .core, .quadriceps, .glutes]
        case .cardio, .cycling, .walking: return [.cardio]
        case .mobility, .yoga, .dance, .recovery: return [.core, .fullBody]
        case .restDay, .custom: return []
        }
    }

    // MARK: - Meals

    static let meals: [MealSuggestion] = [
        MealSuggestion(id: "greek-yogurt-bowl", name: "Greek Yogurt, Berries & Protein Powder", ingredients: ["Greek yogurt", "Mixed berries", "Oats", "Honey", "Protein powder"], approxProteinGramsLow: 30, approxProteinGramsHigh: 40, prepMinutes: 5, dietaryFlags: [.vegetarian], isNoCook: true, costTier: .low),
        MealSuggestion(id: "eggs-veg-tortilla", name: "Eggs, Frozen Veg & Cheese Tortillas", ingredients: ["Eggs", "Frozen mixed vegetables", "Shredded cheese", "Tortillas"], approxProteinGramsLow: 25, approxProteinGramsHigh: 32, prepMinutes: 10, dietaryFlags: [.vegetarian], isNoCook: false, costTier: .low),
        MealSuggestion(id: "rotisserie-rice-bowl", name: "Rotisserie Chicken, Rice & Salsa Bowl", ingredients: ["Rotisserie chicken", "Microwave rice", "Salsa", "Frozen vegetables"], approxProteinGramsLow: 35, approxProteinGramsHigh: 45, prepMinutes: 8, dietaryFlags: [.none], isNoCook: false, costTier: .low),
        MealSuggestion(id: "tuna-yogurt-wrap", name: "Tuna, Greek Yogurt & Seasoning Wrap", ingredients: ["Canned tuna", "Greek yogurt", "Seasoning", "Wraps"], approxProteinGramsLow: 30, approxProteinGramsHigh: 38, prepMinutes: 6, dietaryFlags: [.none], isNoCook: true, costTier: .low),
        MealSuggestion(id: "turkey-pepper-rice", name: "Ground Turkey, Peppers & Rice", ingredients: ["Ground turkey", "Frozen peppers", "Rice", "Seasoning"], approxProteinGramsLow: 32, approxProteinGramsHigh: 40, prepMinutes: 15, dietaryFlags: [.none], isNoCook: false, costTier: .low),
        MealSuggestion(id: "cottage-cheese-bowl", name: "Cottage Cheese, Fruit & Cereal", ingredients: ["Cottage cheese", "Fruit", "Cereal", "Nuts"], approxProteinGramsLow: 24, approxProteinGramsHigh: 30, prepMinutes: 3, dietaryFlags: [.vegetarian], isNoCook: true, costTier: .low),
        MealSuggestion(id: "protein-shake-quick", name: "Quick Protein Shake", ingredients: ["Protein powder", "Milk or water", "Banana (optional)"], approxProteinGramsLow: 20, approxProteinGramsHigh: 30, prepMinutes: 2, dietaryFlags: [.vegetarian], isNoCook: true, costTier: .low),
        MealSuggestion(id: "tofu-stirfry", name: "Tofu & Frozen Vegetable Stir-Fry", ingredients: ["Firm tofu", "Frozen stir-fry vegetables", "Soy sauce", "Rice"], approxProteinGramsLow: 20, approxProteinGramsHigh: 28, prepMinutes: 15, dietaryFlags: [.vegan, .vegetarian, .dairyFree], isNoCook: false, costTier: .medium),
    ]
}
