//
//  TravelModels.swift
//  Myriad
//
//  Created by 洪嘉禺 on 1/19/26.
//

import Foundation
import UIKit

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
    
    // 地图支持
    var countryCode: String?    // 国家代码（例如 "JP", "US"），用于地图显示
    
    // v1.0 照片支持
    var heroImageData: Data?    // 主照片的图片数据
    var memories: [MemoryItem]  // at least one text block recommended

    // 自动计算状态（基于日期）
    var status: TripStatus {
        let now = Date()
        let calendar = Calendar.current
        
        // 获取开始日期的当天起始时间
        let startOfDay = calendar.startOfDay(for: startDate)
        
        // 如果有结束日期，获取结束日期当天的结束时间
        let endOfEndDay: Date?
        if let end = endDate {
            endOfEndDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))
        } else {
            endOfEndDay = nil
        }
        
        if now < startOfDay {
            // 还未开始
            return .planned
        } else if let endDate = endOfEndDay, now >= endDate {
            // 已结束
            return .completed
        } else {
            // 进行中
            return .traveling
        }
    }
    
    // Convenience
    var primaryMemoryText: String? { memories.first?.text }
    
    // 兼容旧代码：heroBackgroundAssetName已废弃，保留以支持迁移
    @available(*, deprecated, message: "Use heroImageData instead")
    var heroBackgroundAssetName: String? { nil }
}
