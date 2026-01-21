//
//  TravelDetailView.swift
//  Myriad
//
//  Created by 洪嘉禺 on 1/19/26.
//

import SwiftUI

struct TravelDetailView: View {

    var store: TravelStore
    let trip: Trip

    @State private var newMemoryText: String = ""
    @State private var showingEditSheet = false

    // 关键：Detail 里不要直接使用传入的 trip 作为“真数据”
    // 因为 trip 是值类型，更新状态后它不会自动变化。
    // 所以用 computed 从 store 中拿“最新版本”
    private var currentTrip: Trip {
        store.trips.first(where: { $0.id == trip.id }) ?? trip
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                heroCard

                memoryComposer

                memoriesSection
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .navigationTitle("旅行事件")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    TripStatusTag(status: currentTrip.status)
                    
                    Button {
                        showingEditSheet = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTripSheet(store: store, trip: currentTrip)
        }
    }

    // MARK: - UI Pieces

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.05))
                .frame(height: 220)
                .overlay(alignment: .topTrailing) {
                    // 背景占位（Phase 1：如果没有 asset，就用渐变/材质）
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.10), Color.black.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    if let imageData = currentTrip.heroImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                }
                .clipped()

            VStack(alignment: .leading, spacing: 8) {
                Text(currentTrip.title)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text(dateLineText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }

    private var memoryComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("记录")
                .font(.headline)

            VStack(spacing: 10) {
                TextField("写下一句话…", text: $newMemoryText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...6)

                HStack {
                    Spacer()
                    Button {
                        store.addMemory(tripID: currentTrip.id, text: newMemoryText)
                        newMemoryText = ""
                    } label: {
                        Text("添加")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(newMemoryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var memoriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("记忆")
                    .font(.headline)

                Spacer()

                Text("\(currentTrip.memories.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if currentTrip.memories.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("还没有记录")
                        .font(.subheadline.weight(.semibold))
                    Text("你可以先从一句话开始，之后再慢慢加照片和地点。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(spacing: 12) {
                    ForEach(currentTrip.memories) { mem in
                        MemoryRow(memory: mem)
                    }
                }
            }
        }
    }

    private var dateLineText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy.MM.dd"
        let start = fmt.string(from: currentTrip.startDate)
        if let end = currentTrip.endDate {
            return "\(start) – \(fmt.string(from: end))"
        } else {
            // 进行中/未定结束：只显示开始
            return start
        }
    }
}

private struct MemoryRow: View {
    let memory: MemoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(timeText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(memory.text)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var timeText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy.MM.dd HH:mm"
        return fmt.string(from: memory.createdAt)
    }
}
