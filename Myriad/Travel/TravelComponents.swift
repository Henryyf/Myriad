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
            .font(.caption.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tagBackgroundGradient)
            )
            .foregroundStyle(tagForeground)
            .overlay(
                Capsule()
                    .stroke(tagForeground.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: tagForeground.opacity(0.15), radius: 4, x: 0, y: 2)
    }

    private var tagBackgroundGradient: LinearGradient {
        switch status {
        case .planned:
            return LinearGradient(
                colors: [
                    Color.orange.opacity(0.2),
                    Color.orange.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .traveling:
            return LinearGradient(
                colors: [
                    Color.green.opacity(0.2),
                    Color.green.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .completed:
            return LinearGradient(
                colors: [
                    Color.blue.opacity(0.2),
                    Color.blue.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
        HStack(spacing: 16) {
            // 图片区域 - 优化设计
            Group {
                if let imageData = trip.heroImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.gray.opacity(0.15),
                                    Color.gray.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary.opacity(0.5))
                        }
                }
            }
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)

            // 内容区域
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(dateText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    TripStatusTag(status: trip.status)
                }

                if let primary = trip.primaryMemoryText, !primary.isEmpty {
                    Text(primary)
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.8))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                // 顶部高光
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
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
