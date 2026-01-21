//
//  CountryFootprint.swift
//  Myriad
//
//  Created by 洪嘉禺 on 1/19/26.
//

import Foundation
import CoreLocation

// MARK: - 国家足迹聚合数据

struct CountryFootprint: Identifiable, Hashable {
    let id: String              // 国家代码（例如 "JP", "US"）
    let name: String            // 国家名称
    let flagEmoji: String       // 国旗 emoji
    let coordinate: CLLocationCoordinate2D  // 国家中心坐标
    let tripIDs: [UUID]         // 关联的旅行ID列表
    let tripsCount: Int         // 旅行数量
    let lastTripDate: Date?     // 最近一次旅行日期
    let status: TripStatus      // 最近旅行的状态
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CountryFootprint, rhs: CountryFootprint) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 国家信息提供者（Phase 1 静态数据）

struct CountryInfo {
    let code: String            // 国家代码
    let name: String            // 中文名称
    let flagEmoji: String       // 国旗 emoji
    let coordinate: CLLocationCoordinate2D  // 中心坐标
    let description: String     // 一句话介绍
}

class CountryInfoProvider {
    
    // Phase 1: 静态国家信息字典（可扩展）
    static let countries: [String: CountryInfo] = [
        "JP": CountryInfo(
            code: "JP",
            name: "日本",
            flagEmoji: "🇯🇵",
            coordinate: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
            description: "樱花、寿司与温泉的国度"
        ),
        "US": CountryInfo(
            code: "US",
            name: "美国",
            flagEmoji: "🇺🇸",
            coordinate: CLLocationCoordinate2D(latitude: 37.0902, longitude: -95.7129),
            description: "自由女神与好莱坞的故乡"
        ),
        "CA": CountryInfo(
            code: "CA",
            name: "加拿大",
            flagEmoji: "🇨🇦",
            coordinate: CLLocationCoordinate2D(latitude: 56.1304, longitude: -106.3468),
            description: "枫叶之国，壮丽的自然风光"
        ),
        "GB": CountryInfo(
            code: "GB",
            name: "英国",
            flagEmoji: "🇬🇧",
            coordinate: CLLocationCoordinate2D(latitude: 55.3781, longitude: -3.4360),
            description: "大本钟与下午茶的绅士之国"
        ),
        "FR": CountryInfo(
            code: "FR",
            name: "法国",
            flagEmoji: "🇫🇷",
            coordinate: CLLocationCoordinate2D(latitude: 46.2276, longitude: 2.2137),
            description: "埃菲尔铁塔与红酒的浪漫之都"
        ),
        "CN": CountryInfo(
            code: "CN",
            name: "中国",
            flagEmoji: "🇨🇳",
            coordinate: CLLocationCoordinate2D(latitude: 35.8617, longitude: 104.1954),
            description: "长城与美食的古老文明"
        ),
        "KR": CountryInfo(
            code: "KR",
            name: "韩国",
            flagEmoji: "🇰🇷",
            coordinate: CLLocationCoordinate2D(latitude: 35.9078, longitude: 127.7669),
            description: "K-pop与韩剧的活力之国"
        ),
        "TH": CountryInfo(
            code: "TH",
            name: "泰国",
            flagEmoji: "🇹🇭",
            coordinate: CLLocationCoordinate2D(latitude: 15.8700, longitude: 100.9925),
            description: "微笑之国，热带风情与佛教文化"
        ),
        "IT": CountryInfo(
            code: "IT",
            name: "意大利",
            flagEmoji: "🇮🇹",
            coordinate: CLLocationCoordinate2D(latitude: 41.8719, longitude: 12.5674),
            description: "古罗马遗迹与披萨的艺术王国"
        ),
        "AU": CountryInfo(
            code: "AU",
            name: "澳大利亚",
            flagEmoji: "🇦🇺",
            coordinate: CLLocationCoordinate2D(latitude: -25.2744, longitude: 133.7751),
            description: "袋鼠与考拉的阳光大陆"
        )
    ]
    
    // 从旅行标题推断国家代码（简化版）
    // Phase 1: 基于常见城市名称映射
    static func inferCountryCode(from title: String) -> String? {
        let titleLower = title.lowercased()
        
        // 日本城市
        if titleLower.contains("tokyo") || titleLower.contains("osaka") || 
           titleLower.contains("kyoto") || titleLower.contains("東京") ||
           titleLower.contains("大阪") || titleLower.contains("京都") {
            return "JP"
        }
        
        // 加拿大城市
        if titleLower.contains("vancouver") || titleLower.contains("toronto") ||
           titleLower.contains("montreal") || titleLower.contains("温哥华") {
            return "CA"
        }
        
        // 美国城市
        if titleLower.contains("new york") || titleLower.contains("los angeles") ||
           titleLower.contains("san francisco") || titleLower.contains("纽约") ||
           titleLower.contains("洛杉矶") {
            return "US"
        }
        
        // 英国城市
        if titleLower.contains("london") || titleLower.contains("伦敦") {
            return "GB"
        }
        
        // 法国城市
        if titleLower.contains("paris") || titleLower.contains("巴黎") {
            return "FR"
        }
        
        // 中国城市
        if titleLower.contains("beijing") || titleLower.contains("shanghai") ||
           titleLower.contains("北京") || titleLower.contains("上海") {
            return "CN"
        }
        
        // 韩国城市
        if titleLower.contains("seoul") || titleLower.contains("首尔") {
            return "KR"
        }
        
        // 泰国城市
        if titleLower.contains("bangkok") || titleLower.contains("曼谷") {
            return "TH"
        }
        
        return nil
    }
    
    // 获取国家信息
    static func getInfo(for countryCode: String) -> CountryInfo? {
        return countries[countryCode]
    }
}
