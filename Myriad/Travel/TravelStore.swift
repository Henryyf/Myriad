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
    
    // iCloud 存储文件路径
    private static let dataFileName = "travel_data.json"
    private var iCloudURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent(Self.dataFileName)
    }
    
    // 本地备份路径（当 iCloud 不可用时使用）
    private var localURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Self.dataFileName)
    }

    init() {
        loadData()
        // 如果加载后仍为空，才使用 mock 数据
        if trips.isEmpty {
            seedMockIfNeeded()
            saveData()
        }
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
        saveData()
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
        saveData()
    }

    func addMemory(tripID: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[idx].memories.insert(MemoryItem(text: trimmed), at: 0)
        saveData()
    }
    
    func deleteMemory(tripID: UUID, memoryID: UUID) {
        guard let tripIdx = trips.firstIndex(where: { $0.id == tripID }) else { return }
        trips[tripIdx].memories.removeAll { $0.id == memoryID }
        saveData()
    }
    
    func deleteTrip(tripID: UUID) {
        trips.removeAll { $0.id == tripID }
        saveData()
    }
    
    // MARK: - iCloud 存储
    
    private func saveData() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(trips)
            
            // 优先保存到 iCloud
            if let iCloudURL = iCloudURL {
                // 确保 iCloud Documents 目录存在
                let documentsDir = iCloudURL.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: documentsDir.path) {
                    try FileManager.default.createDirectory(at: documentsDir, withIntermediateDirectories: true)
                }
                try data.write(to: iCloudURL, options: .atomic)
                print("✅ 数据已保存到 iCloud: \(iCloudURL.path)")
            }
            
            // 同时保存到本地作为备份
            try data.write(to: localURL, options: .atomic)
            print("✅ 数据已保存到本地: \(localURL.path)")
        } catch {
            print("❌ 保存数据失败: \(error.localizedDescription)")
        }
    }
    
    private func loadData() {
        // 优先从 iCloud 加载
        if let iCloudURL = iCloudURL,
           FileManager.default.fileExists(atPath: iCloudURL.path),
           let data = try? Data(contentsOf: iCloudURL) {
            if let loadedTrips = decodeTrips(from: data) {
                trips = loadedTrips
                print("✅ 从 iCloud 加载数据: \(loadedTrips.count) 条旅行记录")
                return
            }
        }
        
        // 如果 iCloud 不可用或加载失败，尝试从本地加载
        if FileManager.default.fileExists(atPath: localURL.path),
           let data = try? Data(contentsOf: localURL) {
            if let loadedTrips = decodeTrips(from: data) {
                trips = loadedTrips
                print("✅ 从本地加载数据: \(loadedTrips.count) 条旅行记录")
                return
            }
        }
        
        print("ℹ️ 未找到已保存的数据，将使用默认数据")
    }
    
    private func decodeTrips(from data: Data) -> [Trip]? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([Trip].self, from: data)
    }

    private func seedMockIfNeeded() {
        guard trips.isEmpty else { return }

        // 预设数据已移除，从空开始
        trips = []
    }
}
