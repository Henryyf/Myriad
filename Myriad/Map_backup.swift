//
//  TravelMapView.swift
//  Myriad
//
//  Created by 洪嘉禺 on 1/19/26.
//
//
//import SwiftUI
//import MapKit
//
//struct TravelMapView: View {
//
//    @Environment(\.colorScheme) private var colorScheme
//    var store: TravelStore
//
//    @State private var selectedCountry: CountryFootprint?
//    @State private var cameraPosition: MapCameraPosition = .automatic
//
//    // 获取所有去过的国家代码集合（统一转换为大写以便匹配）
//    private var visitedCountryCodes: Set<String> {
//        Set(store.trips.compactMap { $0.countryCode?.uppercased() })
//    }
//
//    // 从 trips 聚合国家足迹（显示所有旅行，不筛选状态）
//    private var countryFootprints: [CountryFootprint] {
//        var countryDict: [String: [Trip]] = [:]
//
//        for trip in store.trips {
//            guard let code = trip.countryCode,
//                  let _ = CountryInfoProvider.getInfo(for: code) else {
//                continue
//            }
//            countryDict[code.uppercased(), default: []].append(trip)
//        }
//
//        return countryDict.compactMap { code, trips in
//            guard let info = CountryInfoProvider.getInfo(for: code) else { return nil }
//
//            let sortedTrips = trips.sorted { $0.startDate > $1.startDate }
//            let mostRecentTrip = sortedTrips.first
//
//            return CountryFootprint(
//                id: code,
//                name: info.name,
//                flagEmoji: info.flagEmoji,
//                coordinate: info.coordinate,
//                tripIDs: trips.map { $0.id },
//                tripsCount: trips.count,
//                lastTripDate: mostRecentTrip?.startDate,
//                status: mostRecentTrip?.status ?? .completed
//            )
//        }
//        .sorted { $0.name < $1.name }
//    }
//
//    var body: some View {
//        ZStack(alignment: .bottom) {
//            VStack(spacing: 0) {
//                headerSection
//                mapSection
//            }
//
//            if let country = selectedCountry {
//                countryDetailCard(country)
//                    .transition(.move(edge: .bottom).combined(with: .opacity))
//            }
//        }
//        .navigationTitle("旅行地图")
//        .navigationBarTitleDisplayMode(.inline)
//        .onAppear {
//            cameraPosition = .automatic
//        }
//        .onChange(of: selectedCountry) { _, newValue in
//            if let country = newValue {
//                focusOnCountry(country)
//            }
//        }
//    }
//
//    // MARK: - Header Section
//
//    private var headerSection: some View {
//        VStack(alignment: .leading, spacing: 6) {
//            Text("旅行地图")
//                .font(.title2.bold())
//
//            Text("已解锁 \(countryFootprints.count) 个国家")
//                .font(.subheadline)
//                .foregroundStyle(.secondary)
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .padding(.horizontal)
//        .padding(.top, 10)
//        .padding(.bottom, 12)
//    }
//
//    // MARK: - Map Section
//
//    private var mapSection: some View {
//        GeoJSONMapView(
//            visitedCountryCodes: visitedCountryCodes,
//            countries: countryFootprints,
//            selectedCountry: $selectedCountry,
//            cameraPosition: $cameraPosition
//        )
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//
//    // MARK: - Country Detail Card
//
//    private func countryDetailCard(_ country: CountryFootprint) -> some View {
//        VStack(alignment: .leading, spacing: 16) {
//            HStack(spacing: 12) {
//                Text(country.flagEmoji)
//                    .font(.system(size: 44))
//
//                VStack(alignment: .leading, spacing: 4) {
//                    Text(country.name)
//                        .font(.title3.bold())
//
//                    if let info = CountryInfoProvider.getInfo(for: country.id) {
//                        Text(info.description)
//                            .font(.subheadline)
//                            .foregroundStyle(.secondary)
//                    }
//                }
//
//                Spacer()
//
//                Button {
//                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                        selectedCountry = nil
//                    }
//                } label: {
//                    Image(systemName: "xmark.circle.fill")
//                        .font(.title3)
//                        .foregroundStyle(.secondary)
//                        .symbolRenderingMode(.hierarchical)
//                }
//            }
//
//            HStack(spacing: 20) {
//                StatBadge(icon: "airplane.departure", label: "旅行", value: "\(country.tripsCount)")
//
//                if let lastDate = country.lastTripDate {
//                    StatBadge(icon: "calendar", label: "最近", value: formatDate(lastDate))
//                }
//
//                Spacer()
//            }
//
//            NavigationLink(value: TravelRoute.list) {
//                HStack {
//                    Text("查看该国家的旅行")
//                        .font(.subheadline.weight(.semibold))
//                    Image(systemName: "arrow.right")
//                        .font(.subheadline)
//                }
//                .frame(maxWidth: .infinity)
//                .padding(.vertical, 14)
//                .background(Color.blue.opacity(0.12))
//                .foregroundStyle(Color.blue)
//                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
//            }
//            .buttonStyle(.plain)
//        }
//        .padding(20)
//        .background(.ultraThinMaterial)
//        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
//        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: -4)
//        .padding(.horizontal)
//        .padding(.bottom, 20)
//    }
//
//    // MARK: - Helpers
//
//    private func focusOnCountry(_ country: CountryFootprint) {
//        cameraPosition = .region(
//            MKCoordinateRegion(
//                center: country.coordinate,
//                span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
//            )
//        )
//    }
//
//    private func formatDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy.MM"
//        return formatter.string(from: date)
//    }
//}
//
//// MARK: - Stat Badge
//
//struct StatBadge: View {
//    let icon: String
//    let label: String
//    let value: String
//
//    var body: some View {
//        HStack(spacing: 6) {
//            Image(systemName: icon)
//                .font(.caption)
//                .foregroundStyle(.secondary)
//
//            VStack(alignment: .leading, spacing: 2) {
//                Text(label)
//                    .font(.caption2)
//                    .foregroundStyle(.secondary)
//                Text(value)
//                    .font(.caption.weight(.semibold))
//            }
//        }
//        .padding(.horizontal, 12)
//        .padding(.vertical, 8)
//        .background(Color.black.opacity(0.04))
//        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//    }
//}
//
//// MARK: - GeoJSON Map View (只点亮去过的国家)
//
//struct GeoJSONMapView: UIViewRepresentable {
//    let visitedCountryCodes: Set<String>
//    let countries: [CountryFootprint]
//    @Binding var selectedCountry: CountryFootprint?
//    @Binding var cameraPosition: MapCameraPosition
//
//    func makeUIView(context: Context) -> MKMapView {
//        let mapView = MKMapView()
//        mapView.delegate = context.coordinator
//
//        // 关键：底图用 muted，减少“周边一大片彩色/像被点亮”的干扰
//        let configuration = MKStandardMapConfiguration(elevationStyle: .flat)
//        configuration.emphasisStyle = .muted
//        configuration.pointOfInterestFilter = .excludingAll
//        mapView.preferredConfiguration = configuration
//
//        // 先加载全部国家形状（包含 MultiPolygon），但只渲染 visited overlays
//        context.coordinator.loadGeoJSON()
//        context.coordinator.syncVisitedOverlays(on: mapView, visitedCodes: visitedCountryCodes)
//
//        context.coordinator.addAnnotations(mapView: mapView, countries: countries)
//        return mapView
//    }
//
//    func updateUIView(_ mapView: MKMapView, context: Context) {
//        // 更新标记
//        context.coordinator.updateAnnotations(mapView: mapView, countries: countries)
//
//        // visited 变化时：只增删 visited overlays
//        context.coordinator.syncVisitedOverlays(on: mapView, visitedCodes: visitedCountryCodes)
//
//        // 相机更新（你原逻辑保留）
//        if let targetRegion = context.coordinator.getRegion(from: cameraPosition) {
//            if context.coordinator.lastRegion == nil ||
//                abs(mapView.region.center.latitude - targetRegion.center.latitude) > 0.001 ||
//                abs(mapView.region.center.longitude - targetRegion.center.longitude) > 0.001 {
//                mapView.setRegion(targetRegion, animated: true)
//                context.coordinator.lastRegion = targetRegion
//            }
//        } else {
//            if !countries.isEmpty {
//                let coordinates = countries.map { $0.coordinate }
//                let latitudes = coordinates.map { $0.latitude }
//                let longitudes = coordinates.map { $0.longitude }
//
//                let minLat = latitudes.min()!
//                let maxLat = latitudes.max()!
//                let minLon = longitudes.min()!
//                let maxLon = longitudes.max()!
//
//                let centerLat = (minLat + maxLat) / 2
//                let centerLon = (minLon + maxLon) / 2
//                let latDelta = max((maxLat - minLat) * 1.3, 20)
//                let lonDelta = max((maxLon - minLon) * 1.3, 30)
//
//                let region = MKCoordinateRegion(
//                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
//                    span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
//                )
//                mapView.setRegion(region, animated: true)
//            }
//        }
//    }
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator(parent: self)
//    }
//
//    final class Coordinator: NSObject, MKMapViewDelegate {
//        private let parent: GeoJSONMapView
//
//        // 全量国家形状：ISO_A2 -> [MKPolygon]
//        private var polygonsByISO2: [String: [MKPolygon]] = [:]
//
//        // 当前 map 上已添加的 overlays（只包含 visited）
//        private var activeVisitedOverlays: [MKPolygon] = []
//        private var activeVisitedCodes: Set<String> = []
//
//        var annotations: [String: MKPointAnnotation] = [:]
//        var lastRegion: MKCoordinateRegion?
//
//        init(parent: GeoJSONMapView) {
//            self.parent = parent
//        }
//
//        func getRegion(from position: MapCameraPosition) -> MKCoordinateRegion? {
//            let mirror = Mirror(reflecting: position)
//            for child in mirror.children {
//                if let region = child.value as? MKCoordinateRegion { return region }
//                let childMirror = Mirror(reflecting: child.value)
//                for grandChild in childMirror.children {
//                    if let region = grandChild.value as? MKCoordinateRegion { return region }
//                }
//            }
//            return nil
//        }
//
//        // 只解析一次：读出 ISO_A2，并把 MKPolygon / MKMultiPolygon 都拆成 MKPolygon
//        func loadGeoJSON() {
//            guard polygonsByISO2.isEmpty else { return } // 避免重复解析
//
//            guard let url = Bundle.main.url(forResource: "ne_110m_admin_0_countries", withExtension: "geojson"),
//                  let data = try? Data(contentsOf: url) else {
//                print("⚠️ 无法加载 geoJSON 文件")
//                return
//            }
//
//            do {
//                let geoJSON = try MKGeoJSONDecoder().decode(data)
//
//                var countPolygons = 0
//                var countFeaturesWithISO = 0
//
//                for item in geoJSON {
//                    guard let feature = item as? MKGeoJSONFeature else { continue }
//
//                    var iso2: String? = nil
//                    if let propertiesData = feature.properties,
//                       let jsonObject = try? JSONSerialization.jsonObject(with: propertiesData) as? [String: Any],
//                       let isoA2 = jsonObject["ISO_A2"] as? String,
//                       !isoA2.isEmpty,
//                       isoA2 != "-99" {
//                        iso2 = isoA2.uppercased()
//                        countFeaturesWithISO += 1
//                    }
//
//                    guard let code = iso2 else { continue }
//
//                    for geometry in feature.geometry {
//                        if let polygon = geometry as? MKPolygon {
//                            polygonsByISO2[code, default: []].append(polygon)
//                            countPolygons += 1
//                        } else if let multi = geometry as? MKMultiPolygon {
//                            for p in multi.polygons {
//                                polygonsByISO2[code, default: []].append(p)
//                                countPolygons += 1
//                            }
//                        }
//                    }
//                }
//
//                print("✅ GeoJSON 解析完成：features(with ISO)=\(countFeaturesWithISO)，polygons=\(countPolygons)")
//            } catch {
//                print("❌ 解析 geoJSON 失败: \(error)")
//            }
//        }
//
//        // 只把 visited 国家加到地图上，visited 变化时增删 overlays
//        func syncVisitedOverlays(on mapView: MKMapView, visitedCodes: Set<String>) {
//            let newCodes = Set(visitedCodes.map { $0.uppercased() })
//            guard newCodes != activeVisitedCodes else { return }
//
//            // 移除旧 overlays
//            if !activeVisitedOverlays.isEmpty {
//                mapView.removeOverlays(activeVisitedOverlays)
//                activeVisitedOverlays.removeAll()
//            }
//
//            // 添加新 overlays
//            var newOverlays: [MKPolygon] = []
//            for code in newCodes {
//                if let polys = polygonsByISO2[code], !polys.isEmpty {
//                    newOverlays.append(contentsOf: polys)
//                }
//            }
//
//            if !newOverlays.isEmpty {
//                mapView.addOverlays(newOverlays)
//            }
//
//            activeVisitedOverlays = newOverlays
//            activeVisitedCodes = newCodes
//
//            print("🟦 visited overlays updated: visitedCodes=\(newCodes), overlays=\(newOverlays.count)")
//        }
//
//        // visited overlays：统一蓝色点亮
//        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
//            guard let polygon = overlay as? MKPolygon else {
//                return MKOverlayRenderer(overlay: overlay)
//            }
//
//            let renderer = MKPolygonRenderer(polygon: polygon)
//            renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.70)
//            renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.90)
//            renderer.lineWidth = 2.2
//            return renderer
//        }
//
//        // MARK: - Annotations
//
//        func addAnnotations(mapView: MKMapView, countries: [CountryFootprint]) {
//            for country in countries {
//                let annotation = MKPointAnnotation()
//                annotation.coordinate = country.coordinate
//                annotation.title = country.name
//                annotations[country.id] = annotation
//                mapView.addAnnotation(annotation)
//            }
//        }
//
//        func updateAnnotations(mapView: MKMapView, countries: [CountryFootprint]) {
//            let currentIDs = Set(countries.map { $0.id })
//            let existingIDs = Set(annotations.keys)
//
//            for id in existingIDs.subtracting(currentIDs) {
//                if let annotation = annotations[id] {
//                    mapView.removeAnnotation(annotation)
//                    annotations.removeValue(forKey: id)
//                }
//            }
//
//            for country in countries where annotations[country.id] == nil {
//                let annotation = MKPointAnnotation()
//                annotation.coordinate = country.coordinate
//                annotation.title = country.name
//                annotations[country.id] = annotation
//                mapView.addAnnotation(annotation)
//            }
//        }
//
//        // 你原先自定义 marker 视图如果要保留，也可以在这里继续实现 viewFor / didSelect
//        // 目前默认使用系统 pin，重点是 overlay 点亮正确
//    }
//}
