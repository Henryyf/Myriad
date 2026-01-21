//
//  TravelStore.swift
//  Myriad
//
//  Created by 洪嘉禺 on 1/19/26.
//

import Foundation
import Observation

@Observable
final class TravelStore {

    private(set) var trips: [Trip] = []

    init() {
        seedMockIfNeeded()
    }

    func trips(for status: TripStatus) -> [Trip] {
        trips
            .filter { $0.status == status }
            .sorted { $0.startDate > $1.startDate }
    }

    func addTrip(
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        countryCode: String? = nil,
        heroImageData: Data? = nil,
        firstMemoryText: String = ""
    ) {
        let memoryText = firstMemoryText.trimmingCharacters(in: .whitespacesAndNewlines)
        let memories: [MemoryItem] = memoryText.isEmpty ? [] : [MemoryItem(text: memoryText)]

        let newTrip = Trip(
            title: title,
            startDate: startDate,
            endDate: endDate,
            countryCode: countryCode,
            heroImageData: heroImageData,
            memories: memories
        )
        trips.insert(newTrip, at: 0)
    }
    
    func updateTrip(
        tripID: UUID,
        title: String,
        startDate: Date,
        endDate: Date?,
        countryCode: String?,
        heroImageData: Data?
    ) {
        guard let idx = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[idx].title = title
        trips[idx].startDate = startDate
        trips[idx].endDate = endDate
        trips[idx].countryCode = countryCode
        trips[idx].heroImageData = heroImageData
    }

    func addMemory(tripID: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[idx].memories.insert(MemoryItem(text: trimmed), at: 0)
    }

    private func seedMockIfNeeded() {
        guard trips.isEmpty else { return }

        trips = [
            Trip(
                title: "Tokyo",
                startDate: Date().addingTimeInterval(-86400 * 12),
                endDate: Date().addingTimeInterval(-86400 * 7),
                countryCode: "JP",
                heroImageData: nil,
                memories: [MemoryItem(text: "第一次在浅草看见晚霞，真的很安静。")]
            ),
            Trip(
                title: "Osaka",
                startDate: Date().addingTimeInterval(-86400 * 2),
                endDate: nil,
                countryCode: "JP",
                heroImageData: nil,
                memories: [MemoryItem(text: "今天走了很多路，但吃到一家很棒的拉面。")]
            ),
            Trip(
                title: "Vancouver",
                startDate: Date().addingTimeInterval(86400 * 20),
                endDate: Date().addingTimeInterval(86400 * 26),
                countryCode: "CA",
                heroImageData: nil,
                memories: []
            )
        ]
    }
}
