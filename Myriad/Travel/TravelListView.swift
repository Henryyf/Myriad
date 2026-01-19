//
//  TravelListView.swift
//  Myriad
//
//  Created by 洪嘉禺 on 1/19/26.
//

import SwiftUI

struct TravelListView: View {

    var store: TravelStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                section(status: .traveling)
                section(status: .planned)
                section(status: .completed)

                Spacer(minLength: 24)
            }
            .padding(.horizontal)
            .padding(.top, 10)
        }
        .navigationTitle("旅行列表")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func section(status: TripStatus) -> some View {
        let items = store.trips(for: status)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(status.title)
                    .font(.headline)

                Spacer()

                Text("\(items.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Capsule())
            }

            if items.isEmpty {
                emptyRow(for: status)
            } else {
                VStack(spacing: 12) {
                    ForEach(items, id: \.id) { trip in
                        NavigationLink(value: TravelRoute.detail(trip.id)) {
                            TripCardRow(trip: trip)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func emptyRow(for status: TripStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(emptyTitle(for: status))
                .font(.subheadline.weight(.semibold))
            Text(emptySubtitle(for: status))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func emptyTitle(for status: TripStatus) -> String {
        switch status {
        case .planned: return "还没有计划中的旅行"
        case .traveling: return "目前没有进行中的旅行"
        case .completed: return "还没有已完成的旅行"
        }
    }

    private func emptySubtitle(for status: TripStatus) -> String {
        switch status {
        case .planned: return "点击右上角 + 新建一个旅行事件。"
        case .traveling: return "把旅行状态切到“旅行中”，这里会显示。"
        case .completed: return "完成后切到“已完成”，这里会慢慢积累。"
        }
    }
}
