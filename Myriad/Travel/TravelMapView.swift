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
    
    @State private var selectedCountry: CountryFootprint?
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    // 获取所有去过的国家代码集合（统一转换为大写以便匹配）
    private var visitedCountryCodes: Set<String> {
        Set(store.trips.compactMap { $0.countryCode?.uppercased() })
    }
    
    // 从 trips 聚合国家足迹（显示所有旅行，不筛选状态）
    private var countryFootprints: [CountryFootprint] {
        var countryDict: [String: [Trip]] = [:]
        
        // 按国家分组旅行
        for trip in store.trips {
            // 只使用用户手动选择的国家代码
            guard let code = trip.countryCode,
                  let _ = CountryInfoProvider.getInfo(for: code) else {
                continue
            }
            
            countryDict[code, default: []].append(trip)
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
        .onAppear {
            // 首次加载时使用自动调整
            cameraPosition = .automatic
        }
        .onChange(of: selectedCountry) { oldValue, newValue in
            // 当选中国家时，框选到国家边界
            if let country = newValue {
                focusOnCountry(country)
            }
        }
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
    
    // MARK: - Map Section
    
    private var mapSection: some View {
        GeoJSONMapView(
            visitedCountryCodes: visitedCountryCodes,
            countries: countryFootprints,
            selectedCountry: $selectedCountry,
            cameraPosition: $cameraPosition
        )
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
    
    /// 框选到指定国家的边界
    private func focusOnCountry(_ country: CountryFootprint) {
        // 使用国家坐标点并添加合适的边距
        cameraPosition = .region(
            MKCoordinateRegion(
                center: country.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
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

// MARK: - GeoJSON Map View

struct GeoJSONMapView: UIViewRepresentable {
    let visitedCountryCodes: Set<String>
    let countries: [CountryFootprint]
    @Binding var selectedCountry: CountryFootprint?
    @Binding var cameraPosition: MapCameraPosition
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // 使用标准地图配置，但我们会用覆盖层覆盖所有国家
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat)
        mapView.preferredConfiguration = configuration
        
        // 加载 geoJSON（必须在设置配置之后）
        context.coordinator.loadGeoJSON(mapView: mapView, visitedCodes: visitedCountryCodes)
        
        // 添加国家标记
        context.coordinator.addAnnotations(mapView: mapView, countries: countries)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新国家标记
        context.coordinator.updateAnnotations(mapView: mapView, countries: countries, selectedCountry: selectedCountry)
        
        // 更新 geoJSON 覆盖层颜色
        context.coordinator.updateOverlayColors(mapView: mapView, visitedCodes: visitedCountryCodes)
        
        // 更新相机位置
        // 检查是否有新的 region 需要设置
        if let targetRegion = context.coordinator.getRegion(from: cameraPosition) {
            // 如果有目标 region，更新地图区域
            if context.coordinator.lastRegion == nil || 
               abs(mapView.region.center.latitude - targetRegion.center.latitude) > 0.001 || 
               abs(mapView.region.center.longitude - targetRegion.center.longitude) > 0.001 {
                mapView.setRegion(targetRegion, animated: true)
                context.coordinator.lastRegion = targetRegion
            }
        } else {
            // 如果是 automatic 类型，自动调整到显示所有国家
            if !countries.isEmpty {
                let coordinates = countries.map { $0.coordinate }
                let latitudes = coordinates.map { $0.latitude }
                let longitudes = coordinates.map { $0.longitude }
                
                let minLat = latitudes.min()!
                let maxLat = latitudes.max()!
                let minLon = longitudes.min()!
                let maxLon = longitudes.max()!
                
                let centerLat = (minLat + maxLat) / 2
                let centerLon = (minLon + maxLon) / 2
                let latDelta = max((maxLat - minLat) * 1.3, 20)
                let lonDelta = max((maxLon - minLon) * 1.3, 30)
                
                let region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
                )
                mapView.setRegion(region, animated: true)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: GeoJSONMapView
        var polygonToCountryCode: [MKPolygon: String] = [:]
        var annotations: [String: MKPointAnnotation] = [:]
        var lastRegion: MKCoordinateRegion?
        var renderCount = 0  // 用于调试计数
        
        init(_ parent: GeoJSONMapView) {
            self.parent = parent
        }
        
        // 从 MapCameraPosition 中提取 MKCoordinateRegion
        func getRegion(from position: MapCameraPosition) -> MKCoordinateRegion? {
            // 使用反射来检查 MapCameraPosition 的内部结构
            let mirror = Mirror(reflecting: position)
            for child in mirror.children {
                if let region = child.value as? MKCoordinateRegion {
                    return region
                }
                // 如果子值也是结构体，递归检查
                let childMirror = Mirror(reflecting: child.value)
                for grandChild in childMirror.children {
                    if let region = grandChild.value as? MKCoordinateRegion {
                        return region
                    }
                }
            }
            return nil
        }
        
        func loadGeoJSON(mapView: MKMapView, visitedCodes: Set<String>) {
            guard let url = Bundle.main.url(forResource: "ne_110m_admin_0_countries", withExtension: "geojson"),
                  let data = try? Data(contentsOf: url) else {
                print("⚠️ 无法加载 geoJSON 文件")
                return
            }
            
            do {
                let geoJSON = try MKGeoJSONDecoder().decode(data)
                var polygonCount = 0
                var countryCodeCount = 0
                var polygonWithCodeCount = 0
                var polygonWithoutCodeCount = 0
                
                for item in geoJSON {
                    if let feature = item as? MKGeoJSONFeature {
                        // 获取国家代码（可能为空）
                        var countryCode: String?
                        
                        // MKGeoJSONFeature.properties 是 Data? 类型，需要解码
                        if let propertiesData = feature.properties {
                            if let jsonObject = try? JSONSerialization.jsonObject(with: propertiesData) as? [String: Any],
                               let isoA2 = jsonObject["ISO_A2"] as? String, !isoA2.isEmpty, isoA2 != "-99" {
                                countryCode = isoA2
                                countryCodeCount += 1
                            }
                        }
                        
                        // 为每个多边形创建覆盖层（无论是否有国家代码都要渲染）
                        for geometry in feature.geometry {
                            if let polygon = geometry as? MKPolygon {
                                // 如果有国家代码，统一转换为大写存储；如果没有，存储空字符串
                                if let code = countryCode {
                                    polygonToCountryCode[polygon] = code.uppercased()  // 统一转换为大写
                                    polygonWithCodeCount += 1
                                } else {
                                    // 没有国家代码的国家也存储，但值为空字符串
                                    polygonToCountryCode[polygon] = ""
                                    polygonWithoutCodeCount += 1
                                }
                                mapView.addOverlay(polygon)
                                polygonCount += 1
                            }
                        }
                    }
                }
                print("✅ 成功加载 geoJSON: \(polygonCount) 个多边形")
                print("   有国家代码的多边形: \(polygonWithCodeCount) 个")
                print("   没有国家代码的多边形: \(polygonWithoutCodeCount) 个")
                print("   国家代码种类: \(countryCodeCount) 个")
                print("   访问过的国家: \(visitedCodes)")
            } catch {
                print("❌ 解析 geoJSON 失败: \(error)")
            }
        }
        
        func addAnnotations(mapView: MKMapView, countries: [CountryFootprint]) {
            for country in countries {
                let annotation = MKPointAnnotation()
                annotation.coordinate = country.coordinate
                annotation.title = country.name
                annotations[country.id] = annotation
                mapView.addAnnotation(annotation)
            }
        }
        
        func updateAnnotations(mapView: MKMapView, countries: [CountryFootprint], selectedCountry: CountryFootprint?) {
            let currentIDs = Set(countries.map { $0.id })
            let existingIDs = Set(annotations.keys)
            
            // 移除不存在的标记
            for id in existingIDs.subtracting(currentIDs) {
                if let annotation = annotations[id] {
                    mapView.removeAnnotation(annotation)
                    annotations.removeValue(forKey: id)
                }
            }
            
            // 添加新标记
            for country in countries where annotations[country.id] == nil {
                let annotation = MKPointAnnotation()
                annotation.coordinate = country.coordinate
                annotation.title = country.name
                annotations[country.id] = annotation
                mapView.addAnnotation(annotation)
            }
        }
        
        func updateOverlayColors(mapView: MKMapView, visitedCodes: Set<String>) {
            // 颜色更新在 rendererFor 中实时处理
            // 当覆盖层需要重新渲染时，rendererFor 会自动被调用
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                
                // 根据国家代码判断是否访问过
                if let countryCode = polygonToCountryCode[polygon], !countryCode.isEmpty {
                    // 有国家代码，检查是否访问过（countryCode 已经是大写）
                    let isVisited = parent.visitedCountryCodes.contains(countryCode)
                    
                    // 调试：记录所有被渲染的国家（打印访问过的和部分未访问的）
                    renderCount += 1
                    
                    if isVisited {
                        // 访问过的国家：蓝色填充和边框（明显可见）
                        renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.7)
                        renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.9)
                        renderer.lineWidth = 2.5
                        print("🔵 访问过的国家: \(countryCode) - 蓝色")
                    } else {
                        // 未访问过的国家：使用深灰色完全不透明覆盖默认地图颜色
                        // 使用深灰色确保能够完全覆盖默认地图的彩色，实现黑白效果
                        renderer.fillColor = UIColor(white: 0.75, alpha: 1.0)  // 深灰色，完全不透明
                        renderer.strokeColor = UIColor(white: 0.4, alpha: 1.0)  // 深灰色边框，完全不透明
                        renderer.lineWidth = 1.2
                        
                        // 只打印前10个未访问的国家作为示例
                        if renderCount <= 10 {
                            print("⚫ 未访问的国家: \(countryCode) - 深灰色")
                        }
                    }
                } else {
                    // 没有国家代码，显示为浅灰色覆盖（未访问状态）
                    renderCount += 1
                    if renderCount <= 30 {  // 打印前30个没有代码的多边形
                        let hasEntry = polygonToCountryCode[polygon] != nil
                        let codeValue = polygonToCountryCode[polygon] ?? "nil"
                        print("⚪ 渲染无代码多边形: 字典中有条目=\(hasEntry), 值='\(codeValue)'")
                    }
                    renderer.fillColor = UIColor(white: 0.85, alpha: 1.0)
                    renderer.strokeColor = UIColor(white: 0.5, alpha: 1.0)
                    renderer.lineWidth = 1.0
                }
                
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pointAnnotation = annotation as? MKPointAnnotation else {
                return nil
            }
            
            // 通过坐标查找对应的国家
            guard let country = parent.countries.first(where: { 
                abs($0.coordinate.latitude - pointAnnotation.coordinate.latitude) < 0.01 &&
                abs($0.coordinate.longitude - pointAnnotation.coordinate.longitude) < 0.01
            }) else {
                return nil
            }
            
            let identifier = "countryMarker"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = annotation
            }
            
            // 创建自定义标记视图
            let isSelected = parent.selectedCountry?.id == country.id
            let markerView = createMarkerView(for: country, isSelected: isSelected)
            
            annotationView?.subviews.forEach { $0.removeFromSuperview() }
            annotationView?.addSubview(markerView)
            annotationView?.frame = markerView.bounds
            
            let offset: CGFloat = markerView.bounds.height / 2
            annotationView?.centerOffset = CGPoint(x: 0, y: -offset)
            
            return annotationView
        }
        
        func createMarkerView(for country: CountryFootprint, isSelected: Bool) -> UIView {
            let size: CGFloat = isSelected ? 60 : 48
            let container = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            
            let circle = UIView(frame: container.bounds)
            circle.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
            circle.layer.cornerRadius = size / 2
            circle.clipsToBounds = true
            
            let borderColor: UIColor
            switch country.status {
            case .completed:
                borderColor = UIColor.systemBlue.withAlphaComponent(0.7)
            case .traveling:
                borderColor = UIColor.systemGreen.withAlphaComponent(0.7)
            case .planned:
                borderColor = UIColor.systemOrange.withAlphaComponent(0.7)
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
            container.addSubview(label)
            
            return container
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let pointAnnotation = view.annotation as? MKPointAnnotation else {
                return
            }
            
            // 通过坐标查找对应的国家
            guard let country = parent.countries.first(where: { 
                abs($0.coordinate.latitude - pointAnnotation.coordinate.latitude) < 0.01 &&
                abs($0.coordinate.longitude - pointAnnotation.coordinate.longitude) < 0.01
            }) else {
                return
            }
            
            parent.selectedCountry = country
        }
    }
}
