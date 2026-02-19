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

// MARK: - 国家信息提供者（从 JSON 文件加载）

struct CountryInfo {
    let code: String            // 国家代码
    let name: String            // 中文名称
    let flagEmoji: String       // 国旗 emoji
    let coordinate: CLLocationCoordinate2D  // 中心坐标
    let description: String     // 一句话介绍
}

// JSON 数据结构
private struct CountryData: Codable {
    let code: String
    let name: String
    let flagEmoji: String
    let latitude: Double
    let longitude: Double
    let description: String
}

private struct CountriesJSON: Codable {
    let countries: [CountryData]
}

class CountryInfoProvider {
    
    // 从 JSON 文件加载国家信息
    private static var _countries: [String: CountryInfo]?
    
    static var countries: [String: CountryInfo] {
        if let cached = _countries {
            return cached
        }
        
        guard let url = Bundle.main.url(forResource: "countries", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONDecoder().decode(CountriesJSON.self, from: data) else {
            print("⚠️ 无法加载国家数据 JSON 文件，使用空字典")
            _countries = [:]
            return [:]
        }
        
        var countryDict: [String: CountryInfo] = [:]
        for countryData in json.countries {
            let info = CountryInfo(
                code: countryData.code,
                name: countryData.name,
                flagEmoji: countryData.flagEmoji,
                coordinate: CLLocationCoordinate2D(
                    latitude: countryData.latitude,
                    longitude: countryData.longitude
                ),
                description: countryData.description
            )
            countryDict[countryData.code] = info
        }
        
        _countries = countryDict
        print("✅ 成功加载 \(countryDict.count) 个国家数据")
        return countryDict
    }
    
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
    
    // 获取可选国家列表（用于选择器）
    static var availableCountries: [(code: String, name: String, flag: String)] {
        countries.values
            .map { ($0.code, $0.name, $0.flagEmoji) }
            .sorted { $0.name < $1.name }
    }
}

