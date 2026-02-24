//
//  TravelMapView.swift
//  Myriad
//
//  Created by 洪嘉禺 on 1/19/26.
//

import SwiftUI
import MapKit

struct TravelMapView: View {

    var store: TravelStore

    @State private var selectedCountry: CountryFootprint?
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.8617, longitude: 104.1954),
            span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 80)
        )
    )

    private var visitedCountryCodes: Set<String> {
        Set(store.trips.compactMap { $0.countryCode?.uppercased() })
    }

    private var countryFootprints: [CountryFootprint] {
        var countryDict: [String: [Trip]] = [:]

        for trip in store.trips {
            guard let code = trip.countryCode,
                  let _ = CountryInfoProvider.getInfo(for: code) else {
                continue
            }
            countryDict[code.uppercased(), default: []].append(trip)
        }

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
                headerSection
                mapSection
            }

            if let country = selectedCountry {
                countryDetailCard(country)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("旅行地图")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 35.8617, longitude: 104.1954),
                    span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 80)
                )
            )
        }
        .onChange(of: selectedCountry) { _, newValue in
            guard let country = newValue else { return }
            // 可选：稍微延迟让卡片先弹出更顺滑
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                focusOnCountry(country)
            }
        }
    }

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

    private var mapSection: some View {
        GeoJSONMapView(
            visitedCountryCodes: visitedCountryCodes,
            countries: countryFootprints,
            selectedCountry: $selectedCountry,
            cameraPosition: $cameraPosition
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func countryDetailCard(_ country: CountryFootprint) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部区域 - 优化设计
            HStack(spacing: 16) {
                // 国旗容器 - 添加背景和阴影
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.1),
                                    Color.purple.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                    
                    Text(country.flagEmoji)
                        .font(.system(size: 36))
                }
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(country.name)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    if let info = CountryInfoProvider.getInfo(for: country.id) {
                        Text(info.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selectedCountry = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary.opacity(0.6))
                        .symbolRenderingMode(.hierarchical)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 28, height: 28)
                        )
                }
            }
            .padding(24)
            .padding(.bottom, 20)

            // 统计信息区域 - 美化设计
            HStack(spacing: 20) {
                // 旅行次数卡片
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("\(country.tripsCount)")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                    }
                    Text("次旅行")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.08),
                                    Color.blue.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

                // 最近一次旅行卡片
                if let lastDate = country.lastTripDate {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.purple, Color.purple.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text(formatDate(lastDate))
                                .font(.title2.bold())
                                .foregroundStyle(.primary)
                        }
                        Text("最近一次")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.purple.opacity(0.08),
                                        Color.purple.opacity(0.03)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // 分隔线 - 更精致
            Divider()
                .background(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.secondary.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

            tripsListSection(for: country)
        }
        .background(
            ZStack {
                // 主背景
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                // 顶部渐变装饰
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: -8)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    private func getTripsForCountry(_ country: CountryFootprint) -> [Trip] {
        country.tripIDs
            .compactMap { tripID in store.trips.first(where: { $0.id == tripID }) }
            .sorted { $0.startDate > $1.startDate }
    }

    @ViewBuilder
    private func tripsListSection(for country: CountryFootprint) -> some View {
        let countryTrips = getTripsForCountry(country)

        if countryTrips.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "map")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary.opacity(0.5))
                Text("暂无旅行记录")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // 标题区域 - 优化设计
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.7))
                    
                    Text("旅行记录")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    // 计数徽章 - 更精致
                    Text("\(countryTrips.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.blue,
                                            Color.blue.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(countryTrips, id: \.id) { trip in
                            NavigationLink(value: TravelRoute.detail(trip.id)) {
                                TripCardRow(trip: trip)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .frame(maxHeight: 280)
            }
        }
    }

    private func focusOnCountry(_ country: CountryFootprint) {
        // 更新相机位置，updateUIView 会检测到变化并触发动画
        cameraPosition = .region(
            MKCoordinateRegion(
                center: country.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
            )
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM"
        return formatter.string(from: date)
    }
}

// MARK: - GeoJSON Map View (只灰掉未访问国家，访问国家保持原图)

struct GeoJSONMapView: UIViewRepresentable {
    let visitedCountryCodes: Set<String>
    let countries: [CountryFootprint]
    @Binding var selectedCountry: CountryFootprint?
    @Binding var cameraPosition: MapCameraPosition

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        let configuration = MKStandardMapConfiguration(elevationStyle: .flat)
        configuration.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = configuration

        context.coordinator.loadGeoJSONIfNeeded()
        context.coordinator.syncUnvisitedOverlays(on: mapView, visitedCodes: visitedCountryCodes)

        context.coordinator.addAnnotations(mapView: mapView, countries: countries)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.updateAnnotations(mapView: mapView, countries: countries)
        context.coordinator.updateAnnotationSelection(mapView: mapView, selectedCountry: selectedCountry)

        context.coordinator.syncUnvisitedOverlays(on: mapView, visitedCodes: visitedCountryCodes)
        context.coordinator.handleSelectionChange(mapView: mapView, selectedCountry: selectedCountry)

        // 处理相机位置更新，确保动画能正确触发
        // 注意：当取消卡片时（selectedCountry 为 nil 且 lastRegion 不为 nil），
        // 恢复动画已经在 handleSelectionChange 中处理了，这里跳过避免覆盖
        // 初始加载时（lastRegion 为 nil），需要处理 cameraPosition
        // 选择国家时（selectedCountry 不为 nil），需要处理聚焦动画
        let shouldProcessCamera = context.coordinator.lastRegion == nil || selectedCountry != nil
        if shouldProcessCamera, let targetRegion = context.coordinator.getRegion(from: cameraPosition) {
            let shouldUpdate: Bool
            let needsAnimation: Bool
            
            if let lastRegion = context.coordinator.lastRegion {
                // 比较目标区域和上次记录的区域
                let latDiff = abs(targetRegion.center.latitude - lastRegion.center.latitude)
                let lonDiff = abs(targetRegion.center.longitude - lastRegion.center.longitude)
                let spanLatDiff = abs(targetRegion.span.latitudeDelta - lastRegion.span.latitudeDelta)
                let spanLonDiff = abs(targetRegion.span.longitudeDelta - lastRegion.span.longitudeDelta)
                
                shouldUpdate = latDiff > 0.001 || lonDiff > 0.001 || 
                              spanLatDiff > 0.001 || spanLonDiff > 0.001
                // 如果 lastRegion 存在且区域不同，说明是程序触发的更新，使用动画
                needsAnimation = shouldUpdate
            } else {
                // 首次设置，总是更新，但不使用动画（初始加载）
                shouldUpdate = true
                needsAnimation = false
            }
            
            if shouldUpdate {
                if needsAnimation {
                    // 使用 MapKit 的原生 setRegion 动画
                    // 这会自动提供平滑的中心点移动和缩放过渡
                    // MapKit 内部使用优化的缓动函数，确保动画丝滑
                    mapView.setRegion(targetRegion, animated: true)
                    // lastRegion 会在 regionDidChangeAnimated 中更新
                } else {
                    // 初始加载，不使用动画，立即更新 lastRegion
                    mapView.setRegion(targetRegion, animated: false)
                    context.coordinator.lastRegion = targetRegion
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        private let parent: GeoJSONMapView

        private var polygonsByISO2: [String: [MKPolygon]] = [:]
        private var polygonToCountryCode: [MKPolygon: String] = [:]

        private var activeOverlays: [MKPolygon] = []
        private var activeVisitedCodes: Set<String> = []

        var annotations: [String: MKPointAnnotation] = [:]
        var lastRegion: MKCoordinateRegion?
        private var regionBeforeSelection: MKCoordinateRegion?
        private var lastSelectedCountry: CountryFootprint?

        init(parent: GeoJSONMapView) {
            self.parent = parent
        }

        func getRegion(from position: MapCameraPosition) -> MKCoordinateRegion? {
            let mirror = Mirror(reflecting: position)
            for child in mirror.children {
                if let region = child.value as? MKCoordinateRegion { return region }
                let childMirror = Mirror(reflecting: child.value)
                for grandChild in childMirror.children {
                    if let region = grandChild.value as? MKCoordinateRegion { return region }
                }
            }
            return nil
        }

        // MARK: - GeoJSON

        func loadGeoJSONIfNeeded() {
            guard polygonsByISO2.isEmpty else { return }

            guard let url = Bundle.main.url(forResource: "ne_110m_admin_0_countries", withExtension: "geojson"),
                  let data = try? Data(contentsOf: url) else {
                print("⚠️ 无法加载 geoJSON 文件")
                return
            }

            do {
                let geoJSON = try MKGeoJSONDecoder().decode(data)
                var countPolygons = 0

                for item in geoJSON {
                    guard let feature = item as? MKGeoJSONFeature else { continue }

                    var iso2: String? = nil
                    if let propertiesData = feature.properties,
                       let jsonObject = try? JSONSerialization.jsonObject(with: propertiesData) as? [String: Any] {
                        if let isoA2 = jsonObject["ISO_A2"] as? String,
                           !isoA2.isEmpty,
                           isoA2 != "-99" {
                            iso2 = isoA2.uppercased()
                        } else if let isoA2EH = jsonObject["ISO_A2_EH"] as? String,
                                  !isoA2EH.isEmpty,
                                  isoA2EH != "-99" {
                            iso2 = isoA2EH.uppercased()
                        }
                    }

                    guard let code = iso2 else { continue }

                    for geometry in feature.geometry {
                        if let polygon = geometry as? MKPolygon {
                            polygonsByISO2[code, default: []].append(polygon)
                            polygonToCountryCode[polygon] = code
                            countPolygons += 1
                        } else if let multi = geometry as? MKMultiPolygon {
                            for p in multi.polygons {
                                polygonsByISO2[code, default: []].append(p)
                                polygonToCountryCode[p] = code
                                countPolygons += 1
                            }
                        }
                    }
                }

                print("✅ GeoJSON loaded: polygons=\(countPolygons), countries=\(polygonsByISO2.keys.count)")
            } catch {
                print("❌ 解析 geoJSON 失败: \(error)")
            }
        }

        /// 只把“未访问国家”加为 overlays（灰色遮罩）；访问国家不加 overlay -> 保持地图原色
        func syncUnvisitedOverlays(on mapView: MKMapView, visitedCodes: Set<String>) {
            let newVisited = Set(visitedCodes.map { $0.uppercased() })
            guard newVisited != activeVisitedCodes else { return }

            if !activeOverlays.isEmpty {
                mapView.removeOverlays(activeOverlays)
                activeOverlays.removeAll()
            }

            var unvisited: [MKPolygon] = []
            for (code, polygons) in polygonsByISO2 {
                if !newVisited.contains(code) {
                    unvisited.append(contentsOf: polygons)
                }
            }

            if !unvisited.isEmpty {
                mapView.addOverlays(unvisited)
                activeOverlays = unvisited
            }

            activeVisitedCodes = newVisited
        }

        // MARK: - Overlay Renderer (灰色)

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolygonRenderer(polygon: polygon)
            // 当前 overlays 全部代表“未访问国家”
            renderer.fillColor = UIColor(white: 0.75, alpha: 1.0)
            renderer.strokeColor = UIColor(white: 0.4, alpha: 1.0)
            renderer.lineWidth = 1.2
            return renderer
        }

        // MARK: - Annotations

        func addAnnotations(mapView: MKMapView, countries: [CountryFootprint]) {
            for country in countries {
                let annotation = MKPointAnnotation()
                annotation.coordinate = country.coordinate
                annotation.title = country.name
                annotations[country.id] = annotation
                mapView.addAnnotation(annotation)
            }
        }

        func updateAnnotations(mapView: MKMapView, countries: [CountryFootprint]) {
            let currentIDs = Set(countries.map { $0.id })
            let existingIDs = Set(annotations.keys)

            for id in existingIDs.subtracting(currentIDs) {
                if let annotation = annotations[id] {
                    mapView.removeAnnotation(annotation)
                    annotations.removeValue(forKey: id)
                }
            }

            for country in countries where annotations[country.id] == nil {
                let annotation = MKPointAnnotation()
                annotation.coordinate = country.coordinate
                annotation.title = country.name
                annotations[country.id] = annotation
                mapView.addAnnotation(annotation)
            }
        }

        func updateAnnotationSelection(mapView: MKMapView, selectedCountry: CountryFootprint?) {
            for annotation in mapView.annotations {
                guard let point = annotation as? MKPointAnnotation,
                      let view = mapView.view(for: annotation),
                      let country = parent.countries.first(where: {
                          abs($0.coordinate.latitude - point.coordinate.latitude) < 0.01 &&
                          abs($0.coordinate.longitude - point.coordinate.longitude) < 0.01
                      }) else { continue }

                let isSelected = (selectedCountry?.id == country.id)
                let markerView = createMarkerView(for: country, isSelected: isSelected)

                view.subviews.forEach { $0.removeFromSuperview() }
                view.addSubview(markerView)
                view.frame = markerView.bounds

                let offset: CGFloat = markerView.bounds.height / 2
                view.centerOffset = CGPoint(x: 0, y: -offset)
            }
        }

        // MARK: - Annotation View

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pointAnnotation = annotation as? MKPointAnnotation else { return nil }

            guard let country = parent.countries.first(where: {
                abs($0.coordinate.latitude - pointAnnotation.coordinate.latitude) < 0.01 &&
                abs($0.coordinate.longitude - pointAnnotation.coordinate.longitude) < 0.01
            }) else { return nil }

            let identifier = "countryMarker"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.canShowCallout = false
            view.isEnabled = true

            let isSelected = parent.selectedCountry?.id == country.id
            let markerView = createMarkerView(for: country, isSelected: isSelected)

            view.subviews.forEach { $0.removeFromSuperview() }
            view.addSubview(markerView)
            view.frame = markerView.bounds

            let offset: CGFloat = markerView.bounds.height / 2
            view.centerOffset = CGPoint(x: 0, y: -offset)

            return view
        }

        private func createMarkerView(for country: CountryFootprint, isSelected: Bool) -> UIView {
            let size: CGFloat = isSelected ? 60 : 48
            let container = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            container.isUserInteractionEnabled = false

            let circle = UIView(frame: container.bounds)
            circle.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
            circle.layer.cornerRadius = size / 2
            circle.clipsToBounds = true
            circle.isUserInteractionEnabled = false

            let borderColor: UIColor
            switch country.status {
            case .completed: borderColor = UIColor.systemBlue.withAlphaComponent(0.7)
            case .traveling: borderColor = UIColor.systemGreen.withAlphaComponent(0.7)
            case .planned: borderColor = UIColor.systemOrange.withAlphaComponent(0.7)
            }

            circle.layer.borderWidth = isSelected ? 3 : 2
            circle.layer.borderColor = borderColor.cgColor
            circle.layer.shadowColor = borderColor.cgColor
            circle.layer.shadowOpacity = 0.3
            circle.layer.shadowRadius = isSelected ? 8 : 4
            circle.layer.shadowOffset = CGSize(width: 0, height: 2)

            container.addSubview(circle)

            let label = UILabel(frame: container.bounds)
            label.text = country.flagEmoji
            label.font = UIFont.systemFont(ofSize: isSelected ? 28 : 22)
            label.textAlignment = .center
            label.isUserInteractionEnabled = false
            container.addSubview(label)

            return container
        }

        // MARK: - Selection (唯一 didSelect：避免重复声明)

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let point = view.annotation as? MKPointAnnotation else {
                mapView.deselectAnnotation(view.annotation, animated: false)
                return
            }

            guard let country = parent.countries.first(where: {
                abs($0.coordinate.latitude - point.coordinate.latitude) < 0.01 &&
                abs($0.coordinate.longitude - point.coordinate.longitude) < 0.01
            }) else {
                mapView.deselectAnnotation(view.annotation, animated: false)
                return
            }

            if regionBeforeSelection == nil || parent.selectedCountry == nil {
                regionBeforeSelection = mapView.region
            }

            mapView.deselectAnnotation(view.annotation, animated: false)

            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.parent.selectedCountry = country
                }
            }
        }

        func handleSelectionChange(mapView: MKMapView, selectedCountry: CountryFootprint?) {
            if lastSelectedCountry != nil && selectedCountry == nil {
                if let saved = regionBeforeSelection {
                    // 恢复区域，使用动画
                    mapView.setRegion(saved, animated: true)
                    // 立即更新 lastRegion，防止 updateUIView 中的逻辑覆盖恢复动画
                    lastRegion = saved
                    regionBeforeSelection = nil
                }
            }
            lastSelectedCountry = selectedCountry
        }
        
        // MARK: - Region Change Tracking
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let currentRegion = mapView.region
            
            if animated {
                // 程序触发的动画完成时，更新 lastRegion
                // 这包括选择国家时的聚焦动画和取消卡片时的恢复动画
                lastRegion = currentRegion
            } else {
                // 用户手动拖动地图时，更新 lastRegion
                // 检查当前区域是否与 lastRegion 不同
                if let last = lastRegion {
                    let latDiff = abs(currentRegion.center.latitude - last.center.latitude)
                    let lonDiff = abs(currentRegion.center.longitude - last.center.longitude)
                    if latDiff > 0.001 || lonDiff > 0.001 {
                        // 用户手动拖动，更新 lastRegion
                        lastRegion = currentRegion
                    }
                } else {
                    // lastRegion 为空，直接更新
                    lastRegion = currentRegion
                }
            }
        }
    }
}
