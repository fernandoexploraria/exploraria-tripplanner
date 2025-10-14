/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A SwiftUI view for rendering each day's suggested events.
*/

import FoundationModels
import SwiftUI
import MapKit
import WeatherKit

struct ItineraryView: View {
    let landmark: Landmark
    let itinerary: Itinerary.PartiallyGenerated

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading) {
                if let title = itinerary.title {
                    Text(title)
                        .contentTransition(.opacity)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                if let description = itinerary.description {
                    Text(description)
                        .contentTransition(.opacity)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .top) {
                Image(systemName: "sparkles")
                if let rationale = itinerary.rationale {
                    Text(rationale)
                        .contentTransition(.opacity)
                        .rationaleStyle()
                }
            }
            
            if let days = itinerary.days {
                ForEach(days, id: \.title) { plan in
                    DayView(
                        landmark: landmark,
                        plan: plan
                    )
                }
            }
        }
        .animation(.easeOut, value: itinerary)
        .itineraryStyle()
    }
}

private struct DayView: View {
    let landmark: Landmark
    let plan: DayPlan.PartiallyGenerated

    @State private var mapItem: MKMapItem?
    @State private var weatherText: String?
    @State private var weatherSymbolName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .bottom) {
                LandmarkDetailMapView(
                    landmark: landmark,
                    landmarkMapItem: mapItem
                )
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 6) {
                        if let name = weatherSymbolName {
                            Image(systemName: name)
                                .imageScale(.small)
                        }
                        if let weatherText {
                            Text(weatherText)
                                .transition(.opacity)
                        } else if weatherSymbolName == nil {
                            ProgressView()
                                .scaleEffect(0.7)
                                .progressViewStyle(.circular)
                                .tint(.secondary)
                                .transition(.opacity)
                        }
                    }
                    .font(.footnote)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding([.top, .leading], 12)
                }
                .task(id: plan.destination) {
                    guard let destination = plan.destination, !destination.isEmpty else { return }
                    
                    
                    if let fetchedItem = await LocationLookup().mapItem(atLocation: destination) {
                        self.mapItem = fetchedItem
                    }
                }
                .onChange(of: mapItem) { _, newItem in
                    Task {
                        guard let item = newItem else {
                            await MainActor.run {
                                weatherText = nil
                                weatherSymbolName = nil
                            }
                            return
                        }

                        let loc: CLLocation?
                        if #available(iOS 26.0, *) {
                            loc = item.location
                        } else {
                            loc = item.placemark.location
                        }

                        guard let loc else {
                            await MainActor.run {
                                weatherText = nil
                                weatherSymbolName = nil
                            }
                            return
                        }
                        do {
                            let weather = try await WeatherService.shared.weather(for: loc)
                            let symbolName = weather.currentWeather.symbolName
                            let measurementSystem = Locale.current.measurementSystem
                            let usesMetric = measurementSystem == .metric
                            let temp = weather.currentWeather.temperature
                            let value = usesMetric ? temp.converted(to: .celsius).value : temp.converted(to: .fahrenheit).value
                            let formatted = "\(Int(value))°"
                            await MainActor.run {
                                weatherText = formatted
                                weatherSymbolName = symbolName
                            }
                        } catch {
                            await MainActor.run {
                                weatherText = nil
                                weatherSymbolName = nil
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading) {
                    
                    if let title = plan.title {
                        Text(title)
                            .contentTransition(.opacity)
                            .font(.headline)
                    }
                    if let subtitle = plan.subtitle {
                        Text(subtitle)
                            .contentTransition(.opacity)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .blurredBackground()
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .padding([.horizontal, .top], 4)
            
            ActivityList(activities: plan.activities ?? [])
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
        }
        .padding(.bottom)
        .geometryGroup()
        .card()
        .animation(.easeInOut, value: plan)
    }
    
    
}

private struct ActivityList: View {
    let activities: [Activity].PartiallyGenerated
    
    var body: some View {
        ForEach(activities) { activity in
            HStack(alignment: .top, spacing: 12) {
                if let title = activity.title {
                    ActivityIcon(symbolName: activity.type?.symbolName)
                    VStack(alignment: .leading) {
                        Text(title)
                            .contentTransition(.opacity)
                            .font(.headline)
                        if let description = activity.description {
                            Text(description)
                                .contentTransition(.opacity)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

