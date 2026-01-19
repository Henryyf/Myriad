//
//  TravelModels.swift
//  Myriad
//
//  Created by 洪嘉禺 on 1/19/26.
//

import Foundation

// MARK: - Trip Status

enum TripStatus: String, CaseIterable, Codable, Hashable {
    case planned
    case traveling
    case completed

    var title: String {
        switch self {
        case .planned: return "计划中"
        case .traveling: return "旅行中"
        case .completed: return "已完成"
        }
    }
}

// MARK: - Memory Item (Phase 1: text + optional background)

struct MemoryItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var text: String
}

// MARK: - Trip (Time Event Container)

struct Trip: Identifiable, Codable, Hashable {
    var id: UUID = UUID()

    // Core
    var title: String
    var startDate: Date
    var endDate: Date?          // optional for ongoing or unknown end
    var status: TripStatus

    // v1.0 (DaysMatter-style)
    var heroBackgroundAssetName: String?  // optional image asset name
    var memories: [MemoryItem]            // at least one text block recommended

    // Convenience
    var primaryMemoryText: String? { memories.first?.text }
}
