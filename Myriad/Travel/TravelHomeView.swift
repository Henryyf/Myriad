//
//  TravelHomeView.swift
//  Myriad
//
//  Created by 洪嘉禺 on 1/19/26.
//
import SwiftUI

struct TravelHomeView: View {

    var store: TravelStore
    @State private var showingNewTripSheet = false

    var body: some View {
        ZStack(alignment: .bottom) {

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {

                    header

                    if let recent = store.trips.sorted(by: { $0.startDate > $1.startDate }).first {
                        NavigationLink(value: TravelRoute.detail(recent.id)) {
                            TripCardRow(trip: recent)
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: 14) {
                        NavigationLink(value: TravelRoute.list) {
                            entryRowContent(
                                icon: "list.bullet",
                                title: "旅行列表",
                                subtitle: "所有去过的城市和国家"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(value: TravelRoute.map) {
                            entryRowContent(
                                icon: "map",
                                title: "旅行地图",
                                subtitle: "在世界地图上标记足迹"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer(minLength: 110)
            }
            .navigationTitle("旅行")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingNewTripSheet) {
                NewTripSheet(store: store)
            }

            floatingAddButton
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("旅行足迹")
                .font(.title2.bold())
            Text("你的世界坐标")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private func entryRowContent(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.06))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var floatingAddButton: some View {
        Button {
            showingNewTripSheet = true
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)

                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.bottom, 20)
    }
}
