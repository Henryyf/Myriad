//
//  AnnouncementsView.swift
//  Myriad
//
//  Created by 洪嘉禺 on 2/19/26.
//

import SwiftUI

struct AnnouncementsView: View {

    @State private var announcements: [Announcement] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if announcements.isEmpty && !isLoading {
                ContentUnavailableView(
                    "暂无公告",
                    systemImage: "envelope.open",
                    description: Text("策略调整、市场提醒等重要信息会在这里发布")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(announcements) { item in
                            announcementCard(item)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("公告")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: UUID.self) { id in
            if let item = announcements.first(where: { $0.id == id }) {
                AnnouncementDetailView(announcement: item)
            }
        }
        .task {
            await loadAnnouncements()
        }
    }

    private func announcementCard(_ item: Announcement) -> some View {
        NavigationLink(value: item.id) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if item.isImportant {
                        Text("重要")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.12))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text(item.date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(item.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text(item.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func loadAnnouncements() async {
        // 1. 先尝试从本地缓存加载
        if let cached = loadCachedAnnouncements() {
            announcements = cached
        }
        
        // 2. 异步从 Worker 拉取最新公告
        isLoading = true
        defer { isLoading = false }
        
        let workerURL = "https://seven-star-worker.henryyv0522.workers.dev/announcements?key=myriad-seven-star-2026"
        
        do {
            guard let url = URL(string: workerURL) else { return }
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(AnnouncementsResponse.self, from: data)
            announcements = response.announcements
            
            // 3. 保存到本地缓存
            saveCachedAnnouncements(response.announcements)
        } catch {
            print("加载公告失败: \(error)")
            // Fallback 到默认公告
            if announcements.isEmpty {
                announcements = defaultAnnouncements
            }
        }
    }
    
    // 加载本地缓存
    private func loadCachedAnnouncements() -> [Announcement]? {
        guard let data = UserDefaults.standard.data(forKey: "cached_announcements"),
              let cached = try? JSONDecoder().decode([Announcement].self, from: data) else {
            return nil
        }
        return cached
    }
    
    // 保存到本地缓存
    private func saveCachedAnnouncements(_ items: [Announcement]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "cached_announcements")
        }
    }
    
    // 默认公告（网络失败时使用）
    private var defaultAnnouncements: [Announcement] {
        [
            Announcement(
                id: "default-1",
                title: "七星高照策略上线",
                date: "2026/02/19",
                content: "Trading 模块正式上线！支持七星高照 ETF 轮动策略，每日自动计算调仓信号。",
                isImportant: true
            )
        ]
    }
}

struct Announcement: Identifiable, Codable {
    let id: String
    let title: String
    let date: String
    let content: String
    var isImportant: Bool = false
}

struct AnnouncementsResponse: Codable {
    let version: Int
    let lastUpdated: String
    let announcements: [Announcement]
    
    enum CodingKeys: String, CodingKey {
        case version
        case lastUpdated = "last_updated"
        case announcements
    }
}

// MARK: - 公告详情页

struct AnnouncementDetailView: View {
    let announcement: Announcement

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    if announcement.isImportant {
                        Text("重要")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.12))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text(announcement.date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(announcement.title)
                    .font(.title3.bold())

                Text(announcement.content)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(6)
            }
            .padding(20)
        }
        .navigationTitle("公告详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}
