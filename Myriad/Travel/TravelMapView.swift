//
//  TravelMapView.swift
//  Myriad
//
//  Created by 洪嘉禺 on 1/19/26.
//

import SwiftUI

struct TravelMapView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "globe.asia.australia.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("旅行地图")
                .font(.title3.bold())

            Text("Phase 1：先上线基础结构。\nPhase 2：根据已完成旅行聚合到国家/地区高亮。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.top, 60)
        .navigationTitle("旅行地图")
        .navigationBarTitleDisplayMode(.inline)
    }
}
