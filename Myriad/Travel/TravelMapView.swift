//
//  TravelMapView.swift
//  Myriad
//
//  Created by 洪嘉禺 on 1/19/26.
//

import SwiftUI
import MapKit

struct TravelMapView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    var store: TravelStore
    
    @State private var selectedStatus: StatusFilter = .completed
    @State private var selectedCountry: CountryFootprint?
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    // 筛选选项
    enum StatusFilter: String, CaseIterable {
        case completed = "已完成"
        case traveling = "旅行中"
        case planned = "计划中"
        case all = "全部"
        
        func matches(_ status: TripStatus) -> Bool {
            switch self {
            case .completed: return status == .completed
            case .traveling: return status == .traveling
            case .planned: return status == .planned
            case .all: return true
            }
        }
    }
    
    // 从 trips 聚合国家足迹
    private var countryFootprints: [CountryFootprint] {
        var countryDict: [String: [Trip]] = [:]
        
        // 按国家分组旅行
        for trip in store.trips {
            // 只使用用户手动选择的国家代码
            guard let code = trip.countryCode,
                  let _ = CountryInfoProvider.getInfo(for: code) else {
                continue
            }
            
            // 只包含符合当前筛选条件的旅行
            if selectedStatus.matches(trip.status) {
                countryDict[code, default: []].append(trip)
            }
        }
        
        // 转换为 CountryFootprint
        return countryDict.compactMap { code, trips in
            guard let info = CountryInfoProvider.getInfo(for: code) else { return nil }
            
            let sortedTrips = trips.sorted { $0.startDate > $1.startDate }
            let mostRecentTrip = sortedTrips.first
            
            return CountryFootprint(
                id: code,
                name: info.name,
                flagEmoji: info.flagEmoji,
                coordinate: info.coordinate,
                tripIDs: trips.map { $0.id },
                tripsCount: trips.count,
                lastTripDate: mostRecentTrip?.startDate,
                status: mostRecentTrip?.status ?? .completed
            )
        }
        .sorted { $0.name < $1.name }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // 顶部标题区
                headerSection
                
                // 状态筛选
                statusFilterSection
                
                // 地图
                mapSection
            }
            
            // 底部卡片（选中国家时显示）
            if let country = selectedCountry {
                countryDetailCard(country)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("旅行地图")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("旅行地图")
                .font(.title2.bold())
            
            Text("已解锁 \(countryFootprints.count) 个国家")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
    
    // MARK: - Status Filter
    
    private var statusFilterSection: some View {
        Picker("状态筛选", selection: $selectedStatus) {
            ForEach(StatusFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 12)
        .onChange(of: selectedStatus) { oldValue, newValue in
            // 切换筛选时清除选中
            selectedCountry = nil
            // 根据当前筛选的国家调整视角
            updateCameraPosition()
        }
        .onAppear {
            // 首次加载时设置视角
            updateCameraPosition()
        }
    }
    
    // MARK: - Map Section
    
    private var mapSection: some View {
        Map(position: $cameraPosition, selection: $selectedCountry) {
            ForEach(countryFootprints) { country in
                Annotation(country.name, coordinate: country.coordinate) {
                    CountryMarker(
                        flagEmoji: country.flagEmoji,
                        status: country.status,
                        isSelected: selectedCountry?.id == country.id
                    )
                }
                .tag(country)
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Country Detail Card
    
    private func countryDetailCard(_ country: CountryFootprint) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                // 国旗
                Text(country.flagEmoji)
                    .font(.system(size: 44))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(country.name)
                        .font(.title3.bold())
                    
                    if let info = CountryInfoProvider.getInfo(for: country.id) {
                        Text(info.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // 关闭按钮
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedCountry = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            
            // 统计信息
            HStack(spacing: 20) {
                StatBadge(
                    icon: "airplane.departure",
                    label: "旅行",
                    value: "\(country.tripsCount)"
                )
                
                if let lastDate = country.lastTripDate {
                    StatBadge(
                        icon: "calendar",
                        label: "最近",
                        value: formatDate(lastDate)
                    )
                }
                
                Spacer()
            }
            
            // CTA 按钮
            NavigationLink(value: TravelRoute.list) {
                HStack {
                    Text("查看该国家的旅行")
                        .font(.subheadline.weight(.semibold))
                    
                    Image(systemName: "arrow.right")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue.opacity(0.12))
                .foregroundStyle(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: -4)
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
    
    // MARK: - Helpers
    
    private func updateCameraPosition() {
        let countries = countryFootprints
        
        guard !countries.isEmpty else {
            // 如果没有国家，显示全球视图
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                    span: MKCoordinateSpan(latitudeDelta: 100, longitudeDelta: 150)
                )
            )
            return
        }
        
        // 计算所有国家的边界
        let coordinates = countries.map { $0.coordinate }
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min()!
        let maxLat = latitudes.max()!
        let minLon = longitudes.min()!
        let maxLon = longitudes.max()!
        
        // 计算中心点
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        // 计算跨度，添加30%的边距使视图更宽松
        let latDelta = max((maxLat - minLat) * 1.3, 20)  // 最小20度
        let lonDelta = max((maxLon - minLon) * 1.3, 30)  // 最小30度
        
        cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            )
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM"
        return formatter.string(from: date)
    }
}

// MARK: - Country Marker

struct CountryMarker: View {
    let flagEmoji: String
    let status: TripStatus
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // 背景圆
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: isSelected ? 60 : 48, height: isSelected ? 60 : 48)
                .overlay {
                    Circle()
                        .strokeBorder(markerColor, lineWidth: isSelected ? 3 : 2)
                }
                .shadow(color: markerColor.opacity(0.3), radius: isSelected ? 8 : 4, x: 0, y: 2)
            
            // 国旗 emoji
            Text(flagEmoji)
                .font(.system(size: isSelected ? 28 : 22))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private var markerColor: Color {
        switch status {
        case .completed:
            return Color.blue.opacity(0.7)      // 雾蓝
        case .traveling:
            return Color.green.opacity(0.7)     // 薄荷
        case .planned:
            return Color.orange.opacity(0.7)    // 蜜桃
        }
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
