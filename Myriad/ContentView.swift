import SwiftUI

struct ContentView: View {
    @State private var travelStore = TravelStore()
    @State private var tradingStore = TradingStore()
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.white,
                        Color.gray.opacity(0.06),
                        Color.white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HeaderView()

                        LazyVGrid(columns: columns, spacing: 22) {
                            NavigationLink(value: "travel") {
                                AppIconTile(
                                    title: "旅行",
                                    iconName: "icon_travel"
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: "trading") {
                                AppIconTile(
                                    title: "投资",
                                    iconName: "icon_trading",
                                    iconPadding: 0
                                )
                            }
                            .buttonStyle(.plain)

                            ComingSoonTile(title: "消消乐")
                        }
                        .padding(.top, 10)
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { destination in
                if destination == "travel" {
                    TravelHomeView(store: travelStore)
                } else if destination == "trading" {
                    TradingHomeView(store: tradingStore)
                }
            }
            .navigationDestination(for: TradingRoute.self) { route in
                switch route {
                case .portfolio:
                    TradingHomeView(store: tradingStore)
                case .scanImport:
                    ScanImportSheet(store: tradingStore)
                case .settings:
                    TradingSettingsView(store: tradingStore)
                case .announcements:
                    AnnouncementsView()
                default:
                    EmptyView()
                }
            }
            .navigationDestination(for: TravelRoute.self) { route in
                switch route {
                case .list:
                    TravelListView(store: travelStore)
                case .map:
                    TravelMapView(store: travelStore)
                case .detail(let id):
                    if let trip = travelStore.trips.first(where: { $0.id == id }) {
                        TravelDetailView(store: travelStore, trip: trip)
                    } else {
                        MissingTripView()
                    }
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - Header

struct HeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Myriad")
                .font(.system(size: 35, weight: .bold, design: .rounded))

            Text("指尖所至，万象皆达")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 6)
    }
}

// MARK: - App-like Icon Tile

struct AppIconTile: View {
    let title: String
    let iconName: String
    var iconPadding: CGFloat = 7

    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.95))
                .shadow(radius: 10, y: 6)
                .overlay {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .padding(iconPadding)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                }
                .frame(width: 92, height: 92)

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .contentShape(Rectangle()) 
    }
}

// MARK: - Coming Soon Placeholder (未来模块)

struct ComingSoonTile: View {
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.55))
                .overlay {
                    VStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text("Soon")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .shadow(radius: 6, y: 3)
                .frame(width: 92, height: 92)

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .opacity(0.75)
    }
}

#Preview {
    ContentView()
}

