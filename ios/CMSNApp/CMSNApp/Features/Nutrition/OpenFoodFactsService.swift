import Foundation

/// Thin client for the Open Food Facts API — free, keyless, community
/// database with wide barcode coverage. Chosen over paid options
/// (Nutritionix, FatSecret) at the founder's direction 2026-08-23: no API
/// key to manage, no usage bill, at the cost of occasional gaps in obscure
/// US products.
///
/// All lookups are read-only GETs; nothing about the athlete is sent
/// beyond the search text / barcode itself.
struct OpenFoodFactsService {
    enum ServiceError: LocalizedError {
        case productNotFound
        case badResponse

        var errorDescription: String? {
            switch self {
            case .productNotFound: return "No product found for that barcode. You can add it manually."
            case .badResponse: return "The food database didn't respond. Check your connection and try again."
            }
        }
    }

    /// OFF asks API users to identify their app in the User-Agent.
    private static let userAgent = "CMSNApp/0.1 (iOS prototype)"
    private static let productFields = "code,product_name,brands,nutriments,serving_quantity,serving_size"

    static func product(forBarcode barcode: String) async throws -> FoodProduct {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(trimmed)?fields=\(productFields)") else {
            throw ServiceError.badResponse
        }
        let json = try await fetchJSON(url)
        guard let productJSON = json["product"] as? [String: Any],
              let product = parseProduct(productJSON) else {
            throw ServiceError.productNotFound
        }
        return product
    }

    static func search(_ query: String) async throws -> [FoodProduct] {
        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "25"),
            URLQueryItem(name: "fields", value: productFields),
        ]
        guard let url = components.url else { throw ServiceError.badResponse }
        let json = try await fetchJSON(url)
        let items = json["products"] as? [[String: Any]] ?? []
        // Entries with no macro data at all aren't loggable — drop them
        // rather than show rows that dead-end.
        return items.compactMap(parseProduct).filter {
            $0.proteinPer100g != nil || $0.caloriesPer100g != nil
        }
    }

    private static func fetchJSON(_ url: URL) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ServiceError.badResponse
        }
        return json
    }

    private static func parseProduct(_ json: [String: Any]) -> FoodProduct? {
        let name = (json["product_name"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !name.isEmpty else { return nil }
        let nutriments = json["nutriments"] as? [String: Any] ?? [:]

        func value(_ key: String) -> Double? {
            (nutriments[key] as? Double) ?? (nutriments[key] as? Int).map(Double.init)
                ?? (nutriments[key] as? String).flatMap(Double.init)
        }

        let code = (json["code"] as? String) ?? UUID().uuidString
        // serving_quantity is grams as a number or numeric string.
        let servingGrams = (json["serving_quantity"] as? Double)
            ?? (json["serving_quantity"] as? String).flatMap(Double.init)

        return FoodProduct(
            id: code,
            name: name,
            brand: (json["brands"] as? String)?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces),
            barcode: json["code"] as? String,
            proteinPer100g: value("proteins_100g"),
            carbsPer100g: value("carbohydrates_100g"),
            fatPer100g: value("fat_100g"),
            caloriesPer100g: value("energy-kcal_100g"),
            servingGrams: servingGrams,
            servingDescription: json["serving_size"] as? String
        )
    }
}
