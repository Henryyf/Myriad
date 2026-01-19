//
//  TravelComponents.swift
//  Myriad
//
//  Created by 洪嘉禺 on 1/19/26.
//
import SwiftUI

struct TripStatusTag: View {
    let status: TripStatus

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tagBackground)
            .foregroundStyle(tagForeground)
            .clipShape(Capsule())
    }

    private var tagBackground: Color {
        switch status {
        case .planned: return Color.orange.opacity(0.16)   // 蜜桃黄
        case .traveling: return Color.green.opacity(0.14)  // 薄荷
        case .completed: return Color.blue.opacity(0.14)   // 雾蓝
        }
    }

    private var tagForeground: Color {
        switch status {
        case .planned: return Color.orange
        case .traveling: return Color.green
        case .completed: return Color.blue
        }
    }
}

struct TripCardRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.04))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(trip.title)
                        .font(.headline)

                    Spacer()

                    TripStatusTag(status: trip.status)
                }

                Text(dateText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let primary = trip.primaryMemoryText, !primary.isEmpty {
                    Text(primary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var dateText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy.MM.dd"
        let start = fmt.string(from: trip.startDate)
        if let end = trip.endDate {
            return "\(start) – \(fmt.string(from: end))"
        } else {
            return start
        }
    }
}

struct MissingTripView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("旅行不存在或已被删除")
                .font(.headline)
            Text("返回上一页继续浏览。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("提示")
        .navigationBarTitleDisplayMode(.inline)
    }
}
