import Foundation

/// Bundled education library. Original prose. Every figure below is either
/// taken from a source named in the article or computed from those figures
/// in `CompendiumEnergyExample`. No SwiftData schema change.
///
/// Sources:
/// - Thomas, Erdman, and Burke. Nutrition and Athletic Performance.
///   Med Sci Sports Exerc. 2016;48(3):543-568.
///   https://pubmed.ncbi.nlm.nih.gov/26891166/
/// - Jäger et al. International Society of Sports Nutrition position stand:
///   protein and exercise. J Int Soc Sports Nutr. 2017;14:20.
///   https://jissn.biomedcentral.com/articles/10.1186/s12970-017-0177-8
/// - Herrmann et al. 2024 Adult Compendium of Physical Activities.
///   J Sport Health Sci. 2024;13(1):6-12.
///   https://pmc.ncbi.nlm.nih.gov/articles/PMC10818145/
/// - Compendium conditioning-exercise table (codes 02050–02058):
///   https://pacompendium.com/conditioning-exercise/
/// - Institute of Medicine. Acceptable Macronutrient Distribution Ranges.
///   Table C-5, source note IOM 2002. National Academies Press.
///   https://www.ncbi.nlm.nih.gov/books/NBK208874/
enum EducationLibrary {
    /// Stable id the training-day explanation can open. Do not rename.
    static let fuelAfterTrainingID = "fuel-after-training"

    /// Thomas, Erdman, and Burke 2016: athletes should be referred to a
    /// registered dietitian/nutritionist for a personalized nutrition plan.
    static let notMedicalAdviceNote = "This is not medical advice. A registered dietitian can match these ranges to you. The 2016 joint position of the Academy of Nutrition and Dietetics, Dietitians of Canada, and the American College of Sports Medicine says athletes should be referred to a registered dietitian for a personal plan."

    static let articles: [Article] = [
        fuelAfterTraining,
        howMuchProtein,
        estimatingWorkoutCalories,
        carbsAndTrainingLoad,
        restDaysAndRecovery,
        proteinFromFoodAndSupplements
    ]

    private static let articlesByID: [String: Article] = {
        Dictionary(uniqueKeysWithValues: articles.map { ($0.id, $0) })
    }()

    static func article(id: String) -> Article? {
        articlesByID[id]
    }

    static func articles(in category: ArticleCategory) -> [Article] {
        articles.filter { $0.category == category }
    }

    static func relatedArticles(for article: Article) -> [Article] {
        article.relatedIDs.compactMap { articlesByID[$0] }
    }

    /// Deep link. An unknown id stays on the library root.
    static func destination(openingArticleID: String?) -> LibraryDestination? {
        guard let openingArticleID, article(id: openingArticleID) != nil else { return nil }
        return .article(openingArticleID)
    }

    // MARK: - Citations

    /// Thomas DT, Erdman KA, Burke LM. Med Sci Sports Exerc. 2016;48(3):543-568.
    private static let acsm2016 = ArticleCitation(
        title: "Nutrition and Athletic Performance",
        authorsOrOrg: "Thomas, Erdman, and Burke; Academy of Nutrition and Dietetics, Dietitians of Canada, and the American College of Sports Medicine",
        year: 2016,
        url: citationURL("https://pubmed.ncbi.nlm.nih.gov/26891166/")
    )

    /// Jäger R, et al. J Int Soc Sports Nutr. 2017;14:20.
    private static let issn2017 = ArticleCitation(
        title: "International Society of Sports Nutrition Position Stand: Protein and Exercise",
        authorsOrOrg: "Jäger and colleagues; International Society of Sports Nutrition",
        year: 2017,
        url: citationURL("https://jissn.biomedcentral.com/articles/10.1186/s12970-017-0177-8")
    )

    /// Herrmann SD, et al. J Sport Health Sci. 2024;13(1):6-12.
    private static let compendium2024 = ArticleCitation(
        title: "2024 Adult Compendium of Physical Activities",
        authorsOrOrg: "Herrmann and colleagues",
        year: 2024,
        url: citationURL("https://pmc.ncbi.nlm.nih.gov/articles/PMC10818145/")
    )

    /// Activity codes and MET values, 2024 Adult Compendium.
    private static let compendiumConditioning = ArticleCitation(
        title: "Conditioning Exercise — 2024 Adult Compendium",
        authorsOrOrg: "Compendium of Physical Activities",
        year: 2024,
        url: citationURL("https://pacompendium.com/conditioning-exercise/")
    )

    /// Table C-5. Adults: fat 20–35%, carbohydrate 45–65%, protein 10–35% of energy.
    /// Source note on the table: IOM (2002a).
    private static let amdr = ArticleCitation(
        title: "Acceptable Macronutrient Distribution Ranges",
        authorsOrOrg: "Institute of Medicine, National Academies",
        year: 2002,
        url: citationURL("https://www.ncbi.nlm.nih.gov/books/NBK208874/")
    )

    private static func citationURL(_ string: String) -> URL {
        guard let url = URL(string: string), url.scheme?.lowercased() == "https", url.host != nil else {
            preconditionFailure("Education citation must be an https URL with a host: \(string)")
        }
        return url
    }

    private static func section(_ id: String, _ heading: String, _ body: String) -> ArticleSection {
        ArticleSection(id: id, heading: heading, body: body)
    }

    // MARK: - Articles

    /// Post-session carbohydrate and protein from ACSM 2016 and ISSN 2017.
    /// Speedy refuel: 1–1.2 g carbohydrate/kg/h for the first 4 h when two
    /// fuel-demanding sessions are separated by less than 8 h (Thomas et al. 2016).
    /// Glycogen resynthesis about 5% per hour (Thomas et al. 2016).
    /// Protein after a key session about 0.25–0.3 g/kg or 15–25 g (Thomas et al. 2016).
    /// ISSN per-dose figure: 0.25 g/kg or 20–40 g, about every 3–4 h (Jäger et al. 2017).
    private static let fuelAfterTraining = Article(
        id: fuelAfterTrainingID,
        title: "Fuel after training",
        summary: "After a session, carbohydrate refills muscle fuel and a protein serving supports the repair the position stands describe.",
        category: .fuel,
        sections: [
            section(
                "why-the-next-meal",
                "Why the next meal is part of the session",
                "The 2016 joint position from the Academy of Nutrition and Dietetics, Dietitians of Canada, and the American College of Sports Medicine treats recovery as a nutrition job, not an afterthought. Their statement is that performance of, and recovery from, sport improves when the food and fluid around training are chosen on purpose (Thomas, Erdman, and Burke, 2016)."
            ),
            section(
                "carbohydrate",
                "Carbohydrate when the next session is soon",
                "Muscle glycogen comes back slowly. That paper puts the rate of glycogen resynthesis at about 5% an hour, so the clock starts when you eat, not when you feel hungry (Thomas, Erdman, and Burke, 2016). When two fuel-demanding sessions are less than 8 hours apart, their refueling guide is about 1 to 1.2 g of carbohydrate per kg of body weight each hour for the first 4 hours, then back to the day's usual target (Thomas, Erdman, and Burke, 2016). If the next hard session is farther off, the same paper says the day's total carbohydrate and energy matter more than racing the first hour."
            ),
            section(
                "protein",
                "Protein in the same stretch of hours",
                "The 2016 position describes about 0.25 to 0.3 g of high-quality protein per kg after a key session, which it translates to about 15 to 25 g across a typical range of athlete body sizes (Thomas, Erdman, and Burke, 2016). The International Society of Sports Nutrition's 2017 protein stand uses a close per-meal figure: about 0.25 g per kg, or an absolute dose of 20 to 40 g, spread about every 3 to 4 hours across the day (Jäger and colleagues, 2017). The two papers do not publish one identical window. What they share is a moderate serving, repeated, rather than a single huge dose."
            )
        ],
        citations: [acsm2016, issn2017],
        relatedIDs: ["how-much-protein", "carbs-and-training-load", "estimating-workout-calories"]
    )

    /// Daily protein ranges. ISSN 2017: 1.4–2.0 g/kg/d for most exercisers;
    /// intakes above 3.0 g/kg/d have early body-composition evidence;
    /// 2.3–3.1 g/kg/d may help resistance-trained people keep lean mass in a deficit.
    /// ACSM 2016: 1.2–2.0 g/kg/d, higher for short intensified blocks or reduced energy.
    /// Adult protein AMDR: 10–35% of energy (Institute of Medicine, Table C-5).
    private static let howMuchProtein = Article(
        id: "how-much-protein",
        title: "How much protein",
        summary: "Position stands give a daily range for people who train, then ask you to split it across meals.",
        category: .fuel,
        sections: [
            section(
                "daily-range",
                "A daily range, not one number",
                "The International Society of Sports Nutrition's 2017 stand says 1.4 to 2.0 g of protein per kg of body weight per day is enough for most exercising people who are building or keeping muscle (Jäger and colleagues, 2017). The 2016 joint position puts the intake that supports metabolic adaptation, repair, remodeling, and protein turnover at 1.2 to 2.0 g per kg per day (Thomas, Erdman, and Burke, 2016). Those ranges overlap. They are not a personal prescription, and both papers expect the number to move with training, energy intake, and the food you actually eat."
            ),
            section(
                "deficit",
                "When energy intake is lower",
                "The 2017 stand says there is early evidence that intakes above 3.0 g per kg per day may change body composition in resistance-trained people, including fat mass (Jäger and colleagues, 2017). It also describes a higher range, 2.3 to 3.1 g per kg per day, that may help resistance-trained people keep lean mass during a calorie deficit (Jäger and colleagues, 2017). The 2016 position says higher intakes can be appropriate for short stretches of intensified training or when energy intake drops, and that about 2.0 g per kg per day or higher, spread across the day, may help limit loss of fat-free mass when energy is restricted (Thomas, Erdman, and Burke, 2016). Read those as published ranges for a specific situation, not as a target to chase by default."
            ),
            section(
                "per-meal",
                "What a single eating occasion looks like",
                "The 2017 stand's general per-serving figure is about 0.25 g of high-quality protein per kg, or 20 to 40 g, ideally about every 3 to 4 hours (Jäger and colleagues, 2017). The 2016 position highlights about 0.3 g per kg after key sessions and about every 3 to 5 hours, and the 0.25 to 0.3 g per kg (about 15 to 25 g) figure after hard work (Thomas, Erdman, and Burke, 2016). Total intake over the day is the part both papers treat as the main lever."
            ),
            section(
                "amdr",
                "Where that sits in the whole diet",
                "For adults, the Acceptable Macronutrient Distribution Range for protein is 10 to 35% of energy (Institute of Medicine, National Academies). The 2017 stand notes that its 1.4 to 2.0 g per kg range falls inside that distribution range (Jäger and colleagues, 2017). A percentage of calories and a gram-per-kilogram target answer different questions. The gram target scales with body weight. The percentage describes the mix of the whole diet."
            )
        ],
        citations: [issn2017, acsm2016, amdr],
        relatedIDs: ["fuel-after-training", "protein-from-food-and-supplements", "rest-days-and-recovery"]
    )

    /// MET estimates. Herrmann et al. 2024: 1 MET ≈ 1 kcal/kg/h; values are not
    /// precise individual energy expenditure; 912 of 1114 activities measured,
    /// 202 estimated; one cited comparison differed by about 8–15%.
    /// Codes and MET values from the 2024 conditioning table, as listed in the
    /// shared source notes: 02054 3.5, 02050 6.0, 02052 5.0, 02055 5.8,
    /// 02056 3.0, 02057 6.5, 02058 9.8. Adult compendium ages 19–59.
    private static let estimatingWorkoutCalories: Article = {
        let met = CitedNumberFormat.string(CompendiumEnergyExample.met)
        let net = CitedNumberFormat.string(CompendiumEnergyExample.netMET)
        let kilograms = CitedNumberFormat.string(CompendiumEnergyExample.exampleBodyweightKG)
        let minutes = CitedNumberFormat.string(CompendiumEnergyExample.exampleMinutes)
        let hours = CitedNumberFormat.string(CompendiumEnergyExample.exampleHours)
        let kcal = CitedNumberFormat.string(CompendiumEnergyExample.exampleKcalAboveRest)
        return Article(
            id: "estimating-workout-calories",
            title: "Estimating workout calories",
            summary: "A session calorie figure here is a Compendium estimate above rest, not a lab measurement.",
            category: .training,
            sections: [
                section(
                    "what-a-met-is",
                    "What a MET is",
                    "The 2024 Adult Compendium assigns a metabolic equivalent, a MET, to hundreds of activities so studies can compare them. Herrmann and colleagues define that unit against a standard resting rate: 1 MET is about 1 kcal per kg of body weight per hour. The adult list is built for ages 19 to 59 (Herrmann and colleagues, 2024). It is a lookup table of typical costs, compiled so different studies mean the same thing by a given activity."
                ),
                section(
                    "codes",
                    "Resistance codes this library uses",
                    "When a session looks like ordinary lifting, the conditioning table supplies a code instead of a guessed intensity. Code 02054, resistance training with multiple exercises at about 8 to 15 reps, is \(met) MET. Code 02050, vigorous resistance training or powerlifting, is 6.0 MET. Code 02052, squats or deadlift, is 5.0 MET. Code 02055, circuit training or supersets, is 5.8 MET. Code 02056, general bodyweight work, is 3.0 MET. Code 02057, high-intensity bodyweight work, is 6.5 MET. Code 02058, kettlebell swings, is 9.8 MET (Herrmann and colleagues, 2024; Compendium of Physical Activities conditioning table). The match is conservative: a session that does not clearly fit one of those descriptions should not inherit the highest code."
                ),
                section(
                    "above-rest",
                    "Above rest, not the whole day",
                    "A MET already includes rest, because 1 MET is that resting rate of about 1 kcal per kg per hour (Herrmann and colleagues, 2024). Counting the full MET and a separate resting-energy estimate would count that rest twice. This library subtracts 1 MET first, then multiplies by body weight and hours. Code \(CompendiumEnergyExample.code) is \(met) MET, so \(met) minus 1 leaves \(net). The \(kilograms) kg and the \(minutes) minutes in this paragraph are example inputs, not a person we measured. \(minutes) minutes is \(hours) hours. \(net) times \(kilograms) times \(hours) equals \(kcal) kcal above rest. Change the weight, the minutes, or the code, and the product changes. The arithmetic is the estimate."
                ),
                section(
                    "error",
                    "Treat it as an estimate",
                    "Herrmann and colleagues say people use the Compendium to estimate an individual's energy expenditure, and that it does not reflect a precise personal measurement. Several things shift resting rate and the cost of an activity, including age, sex, height, and body weight. In one comparison they cite, energy cost during treadmill walking was about 8 to 15% higher in women with obesity than in women without obesity (Herrmann and colleagues, 2024). That is an illustration of spread, not an error bar measured on your set of squats. Of the 1114 activities in the 2024 adult list, 912 have a measured MET value and 202 are estimated (Herrmann and colleagues, 2024). Use the figure to see scale. It is not a calorie you burned to the gram."
                )
            ],
            citations: [compendium2024, compendiumConditioning],
            relatedIDs: ["fuel-after-training", "carbs-and-training-load"]
        )
    }()

    /// Daily carbohydrate by training load, Thomas et al. 2016:
    /// light 3–5 g/kg/d, moderate (~1 h/d) 5–7, high (1–3 h/d) 6–10,
    /// very high (>4–5 h/d) 8–12. Fat for most athletes 20–35% of energy,
    /// and chronic intakes below 20% are discouraged. Adult AMDR:
    /// fat 20–35%, carbohydrate 45–65%, protein 10–35% (IOM Table C-5).
    private static let carbsAndTrainingLoad = Article(
        id: "carbs-and-training-load",
        title: "Carbs and training load",
        summary: "Daily carbohydrate in the 2016 position scales with how long and how hard the training is.",
        category: .fuel,
        sections: [
            section(
                "load-table",
                "The day follows the work",
                "The 2016 joint position publishes daily carbohydrate targets for days when high carbohydrate availability matters — hard or high-quality sessions, not every hour of every week (Thomas, Erdman, and Burke, 2016). Light work, meaning low intensity or skill-based activity, is 3 to 5 g per kg per day. A moderate program, about 1 hour a day, is 5 to 7 g per kg per day. A high load, about 1 to 3 hours a day of moderate to high intensity, is 6 to 10 g per kg per day. A very high load, more than about 4 to 5 hours a day at that intensity, is 8 to 12 g per kg per day. The paper says those targets should be tuned to total energy needs, the session, and how training actually feels."
            ),
            section(
                "not-every-day",
                "High availability is not every day",
                "The same note says the targets above are for sessions where quality or intensity matters. When that matters less, it may matter less to hit them. Carbohydrate can then follow energy goals, what you like to eat, and what you have (Thomas, Erdman, and Burke, 2016). The paper also describes a separate case, outside ordinary rest, where someone deliberately trains with low carbohydrate availability to chase a training adaptation. That is a planned tactic, not what a normal rest day is doing."
            ),
            section(
                "fat",
                "Fat stays inside a public range",
                "The 2016 position says fat intake for most athletes lands around 20 to 35% of energy, in line with public health guidance, and that chronically eating below 20% of energy from fat is unlikely to help performance and can shrink the foods you need for essential fats and fat-soluble vitamins (Thomas, Erdman, and Burke, 2016). For adults, the Acceptable Macronutrient Distribution Ranges are fat 20 to 35% of energy, carbohydrate 45 to 65%, and protein 10 to 35% (Institute of Medicine, National Academies). A training-day plate that pushes carbohydrate up still has to leave room for that fat range."
            )
        ],
        citations: [acsm2016, amdr],
        relatedIDs: ["fuel-after-training", "rest-days-and-recovery", "estimating-workout-calories"]
    )

    /// Rest and recovery from Thomas et al. 2016 only.
    /// Glycogen can normalize with ~24 h of reduced training plus adequate fuel.
    /// Light-load carbohydrate is 3–5 g/kg/d. Speedy refuel (1–1.2 g/kg/h for 4 h)
    /// applies when two fuel-demanding sessions are <8 h apart.
    /// Daily protein 1.2–2.0 g/kg/d (ACSM) and 1.4–2.0 g/kg/d (ISSN 2017).
    private static let restDaysAndRecovery = Article(
        id: "rest-days-and-recovery",
        title: "Rest days and recovery",
        summary: "A day with less training still has a fuel job: carbohydrate can come down, and protein is still spread through the day.",
        category: .recovery,
        sections: [
            section(
                "recovery-is-in-scope",
                "Recovery is in the position, not beside it",
                "The 2016 joint position is about performance and recovery. It is not a training-day-only document (Thomas, Erdman, and Burke, 2016). On glycogen, it says that without severe muscle damage, stores can be brought back toward normal with about 24 hours of reduced training and enough fuel (Thomas, Erdman, and Burke, 2016). A rest day is that kind of window when the next hard session is a day away, not a second session tonight."
            ),
            section(
                "carbohydrate-comes-down",
                "Carbohydrate comes down with the work",
                "The light-load range in that paper is 3 to 5 g of carbohydrate per kg per day, for low-intensity or skill-based activity (Thomas, Erdman, and Burke, 2016). A day with no long session sits nearer that description than the high-load range of 6 to 10 g per kg, which is written for about 1 to 3 hours of moderate to high intensity work (Thomas, Erdman, and Burke, 2016). The paper also says that when quality and intensity matter less, it may matter less to hit the high-availability targets. The fast refuel figure — about 1 to 1.2 g per kg each hour for the first 4 hours — is for the case where two fuel-demanding sessions are less than 8 hours apart (Thomas, Erdman, and Burke, 2016). A full rest day usually is not that gap."
            ),
            section(
                "protein-stays",
                "Protein does not take the day off",
                "Daily protein in the 2016 position is still about 1.2 to 2.0 g per kg, spread through the day (Thomas, Erdman, and Burke, 2016). The 2017 protein stand's range for most exercising people is 1.4 to 2.0 g per kg per day, in doses about every 3 to 4 hours (Jäger and colleagues, 2017). Rest changes the carbohydrate demand because the fuel cost of the day changed. It does not erase the protein range those papers publish for people who train."
            )
        ],
        citations: [acsm2016, issn2017],
        relatedIDs: ["carbs-and-training-load", "how-much-protein", "fuel-after-training"]
    )

    /// Whole food vs supplemental protein. ISSN 2017: daily protein can come
    /// from whole foods; supplements are a practical option. ACSM 2016:
    /// when whole-food protein is inconvenient, a portable supplement may
    /// help, and advice should stay conservative. Per-dose 0.25 g/kg or
    /// 20–40 g is the ISSN general figure. RD referral is ACSM 2016.
    private static let proteinFromFoodAndSupplements = Article(
        id: "protein-from-food-and-supplements",
        title: "Protein from food or a supplement",
        summary: "Whole foods can cover a protein target. A supplement is a way to carry a serving, not a separate requirement.",
        category: .supplements,
        sections: [
            section(
                "food-first",
                "Food can do the job",
                "The 2017 protein stand says physically active people can meet daily protein from whole foods. It also says a supplement is a practical way to hit protein quality and amount while holding calories down, especially when training volume is high (Jäger and colleagues, 2017). The same stand tells athletes to focus on whole foods that contain all of the essential amino acids, because those amino acids are what stimulate muscle protein synthesis. A powder is not a second nutrition plan. It is one way to eat a serving you already meant to eat."
            ),
            section(
                "when-a-shake-is-just-food",
                "When a shake is just food you can carry",
                "The 2016 joint position says that when whole-food protein is not convenient or available, a portable supplement with high-quality ingredients may be a practical stand-in, and that advice about protein supplements should stay conservative: aimed at recovery and adaptation, with diet quality still the priority (Thomas, Erdman, and Burke, 2016). That paper also says athletes should be referred to a registered dietitian for a personal plan. This library does not pick a brand, and it does not set a dose for you."
            ),
            section(
                "a-serving",
                "A serving, not a product pitch",
                "The 2017 stand's general per-serving figure is about 0.25 g of high-quality protein per kg, or 20 to 40 g (Jäger and colleagues, 2017). That is the same serving size the protein article uses for meals. If a label's scoop is how you hit one of those servings, the scoop is doing a food's job. The supplement notes already in this app stay the place to read what a specific product category is, and what they do not claim."
            )
        ],
        citations: [issn2017, acsm2016],
        relatedIDs: ["how-much-protein", "fuel-after-training"]
    )
}
