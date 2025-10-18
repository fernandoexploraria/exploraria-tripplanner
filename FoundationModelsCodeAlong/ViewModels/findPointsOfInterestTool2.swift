import FoundationModels
import SwiftUI
import MapKit

@Observable
final class FindPointsOfInterestTool2: Tool {
    
    let name = "findPointsOfInterest"
    let description = "Finds points of interest for a landmark."
    
    let landmark: Landmark
    init(landmark: Landmark) {
        self.landmark = landmark
    }

    @Generable
    struct Arguments {
        @Guide(description: "This is the point of interest we are going to search activities.")
        let pointOfInterest: String
    }
    
    func call(arguments: Arguments) async throws -> String {
        guard let placeID = landmark.placeID else {
            return "Error: Missing place ID for landmark."
        }
        let results = await getSuggestions(pointOfInterest: arguments.pointOfInterest,
                                           landmarkPlaceID: placeID)
        return """
        There are these activities in \(arguments.pointOfInterest): 
        \(results.joined(separator: ", "))
        """
    }
}

func getSuggestions(pointOfInterest: String, landmarkPlaceID: String) async -> [String] {
    // Resolve the Apple Place ID to an MKMapItem
    guard let identifier = MKMapItem.Identifier(rawValue: landmarkPlaceID) else {
        return []
    }
    do {
        let requestItem = MKMapItemRequest(mapItemIdentifier: identifier)
        let item = try await requestItem.mapItem

        // Build a search request centered around the item's coordinate
        let searchRequest = MKLocalSearch.Request()
        // searchRequest.naturalLanguageQuery = pointOfInterest
        searchRequest.naturalLanguageQuery = "points of interest"
        searchRequest.resultTypes = .pointOfInterest

        // Create a 10,000 meter region around the item
        let center = item.location.coordinate
        let region = MKCoordinateRegion(center: center,
                                        latitudinalMeters: 10_000,
                                        longitudinalMeters: 10_000)
        searchRequest.region = region

        // Apply the same curated list of tourist-relevant POI categories used elsewhere
        let categories: [MKPointOfInterestCategory] = [
            .museum, .landmark, .park, .nationalPark, .beach, .marina, .aquarium,
            .amusementPark, .stadium, .theater, .movieTheater, .nightlife, .winery,
            .brewery, .library, .university, .campground
        ]
        searchRequest.pointOfInterestFilter = MKPointOfInterestFilter(including: categories)

        // Execute the search
        let response = try await MKLocalSearch(request: searchRequest).start()
        // Map to names, filter out empties, and return a concise list
        let names = response.mapItems.compactMap { $0.name?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(names.prefix(20))
    } catch {
        return []
    }
}
