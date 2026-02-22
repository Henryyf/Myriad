//
//  TradingHomeView.swift
//  Myriad
//
//  Created by 洪嘉禺 on 2/17/26.
//

import SwiftUI
import PhotosUI

struct TradingHomeView: View {

    var store: TradingStore
    @State private var showingScanSheet = false
    @State private var latestSignal: StrategySignal?
    @State private var classified: [ClassifiedHolding] = []
    @State private var advices: [String: HoldingAction] = [:]
    @State private var buyAdviceNames: [String] = []
    @State private var signalError: String?
    @State private var isLoadingSignal = false
    @State private var strategy = SevenStarStrategy()
    @State private var notificationManager = NotificationManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                todayActionCard
                assetOverview
                holdingsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationTitle("Trading")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    NavigationLink(value: TradingRoute.announcements) {
                        Image(systemName: "envelope")
                            .font(.system(size: 15, weight: .medium))
                    }
                    NavigationLink(value: TradingRoute.settings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15, weight: .medium))
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            scanButton
        }
        .sheet(isPresented: $showingScanSheet) {
            ScanImportSheet(store: store)
        }
        .task {
            await fetchSignal()
            await setupNotifications()
        }
    }

    // MARK: - 今日操作卡（信号 + 操作建议统一展示）

    private var todayActionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoadingSignal {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在计算今日信号…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            } else if let signal = latestSignal {
                // 顶部：日期 + 状态
                HStack {
                    Text(formatSignalDate(signal.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(signal.status == "signal" ? "调仓" : "防御")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(signal.status == "signal"
                                ? Color.red.opacity(0.12)
                                : Color.blue.opacity(0.12))
                        )
                        .foregroundStyle(signal.status == "signal" ? .red : .blue)
                }

                // 操作列表（买入、卖出、加仓、减仓、持有不变）
                let actions = allActions
                if actions.isEmpty {
                    Text("今日无需操作，继续持有")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(actions, id: \.name) { item in
                            HStack(spacing: 10) {
                                // 操作类型色条
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(item.action.displayColor)
                                    .frame(width: 3, height: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.subheadline.bold())
                                    if let detail = item.detail {
                                        Text(detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Text(item.action.rawValue)
                                    .font(.caption.bold())
                                    .foregroundStyle(item.action.displayColor)
                            }
                        }
                    }
                }
            } else if signalError != nil {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("信号获取失败")
                            .font(.subheadline.bold())
                        Text("请检查网络连接后重试")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 资产概览

    private var assetOverview: some View {
        VStack(spacing: 12) {
            // 总资产
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("总资产")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("¥\(formatCurrency(store.portfolio.totalCapital))")
                        .font(.title2.bold().monospacedDigit())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("可用现金")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("¥\(formatCurrency(store.portfolio.cashBalance))")
                        .font(.callout.monospacedDigit())
                }
            }

            // 仓位条
            let config = store.portfolio.strategyConfig
            let stratPct = Int(round(config.strategyPercent * 100))
            let freePct = Int(round(config.freePlayPercent * 100))
            let cashPct = 100 - stratPct - freePct  // 保证加起来 = 100
            GeometryReader { geo in
                HStack(spacing: 1.5) {
                    if stratPct > 0 {
                        allocationSegment(
                            width: geo.size.width * config.strategyPercent,
                            color: .blue, label: "策略 \(stratPct)%"
                        )
                    }
                    if freePct > 0 {
                        allocationSegment(
                            width: geo.size.width * config.freePlayPercent,
                            color: .purple, label: "自选 \(freePct)%"
                        )
                    }
                    if cashPct > 0 {
                        allocationSegment(
                            width: geo.size.width * config.cashPercent,
                            color: .gray.opacity(0.4), label: "现金 \(cashPct)%"
                        )
                    }
                }
            }
            .frame(height: 22)

            // 今日未更新提醒
            if !store.isUpdatedToday {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("今日尚未更新持仓")
                        .font(.caption)
                }
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func allocationSegment(width: CGFloat, color: Color, label: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
            Text(label)
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.white)
        }
        .frame(width: max(width, 0))
    }

    // MARK: - 持仓列表

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack {
                Text("持仓")
                    .font(.subheadline.bold())
                Spacer()
                if !store.portfolio.holdings.isEmpty {
                    Text("\(store.portfolio.holdings.count) 只")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if store.portfolio.holdings.isEmpty && buyAdviceNames.isEmpty {
                // 空状态
                emptyState
            } else {
                // 策略仓持仓
                let strategyHoldings = classified.filter { $0.category == .strategy || $0.category == .mixed }
                if !strategyHoldings.isEmpty {
                    Text("策略仓")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(strategyHoldings) { ch in
                        HoldingRow(
                            holding: ch.holding,
                            action: ch.action,
                            badge: ch.category == .mixed ? "混合" : nil,
                            strategyShares: ch.strategyShares,
                            freePlayShares: ch.freePlayShares
                        )
                    }
                }

                // 自选仓持仓
                let freePlayHoldings = classified.filter { $0.category == .freePlay }
                if !freePlayHoldings.isEmpty {
                    Text("自选仓")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, strategyHoldings.isEmpty ? 0 : 4)
                    ForEach(freePlayHoldings) { ch in
                        HoldingRow(holding: ch.holding, action: nil)
                    }
                }
            }
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.text.clipboard")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(.quaternary)

            VStack(spacing: 4) {
                Text("还没有持仓记录")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("拍摄东方财富持仓截图即可导入")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - 底部扫描按钮

    private var scanButton: some View {
        Button {
            showingScanSheet = true
        } label: {
            Label("扫描持仓", systemImage: "doc.viewfinder")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.primary)
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(.bar)
    }

    // MARK: - 操作汇总逻辑

    private struct ActionItem {
        let name: String
        let action: HoldingAction
        let detail: String?
    }

    /// 把所有操作建议合并成一个列表（去重）
    private var allActions: [ActionItem] {
        var items: [ActionItem] = []

        // 当前持仓的建议（卖出、加仓、减仓，跳过买入——由下面统一处理）
        for (name, action) in advices {
            if action == .match || action == .hold || action == .buy { continue }
            items.append(ActionItem(name: name, action: action, detail: nil))
        }

        // 未持有的买入建议（唯一的买入入口）
        for name in buyAdviceNames {
            if store.portfolio.totalCapital > 0,
               let signal = latestSignal,
               let target = signal.targetHoldings.first(where: { $0.etfName == name }),
               target.targetShares > 0 {
                items.append(ActionItem(
                    name: name,
                    action: .buy,
                    detail: "约 \(target.targetShares) 股 · ¥\(formatCurrency(target.targetValue))"
                ))
            } else {
                items.append(ActionItem(name: name, action: .buy, detail: "扫描持仓后显示具体金额"))
            }
        }

        return items
    }

    // MARK: - 信号获取（本地计算，直接调 Tushare）

    private func fetchSignal() async {
        isLoadingSignal = true
        signalError = nil

        let capital = store.portfolio.strategyBudget > 0
            ? store.portfolio.strategyBudget
            : store.portfolio.totalCapital > 0
                ? store.portfolio.totalCapital
                : 100_000

        // 1. 优先从云端拉取信号
        let workerURL = "https://myriad-api.henryyv0522.workers.dev/signal/latest?key=myriad-seven-star-2026"
        
        do {
            guard let url = URL(string: workerURL) else {
                throw URLError(.badURL)
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            let signal = try JSONDecoder().decode(StrategySignal.self, from: data)
            latestSignal = signal
            
            // 保存到本地缓存（离线可用）
            if let encoded = try? JSONEncoder().encode(signal) {
                UserDefaults.standard.set(encoded, forKey: "cached_signal")
            }
            
            classified = store.classifyHoldings(signal: signal)
            updateAdvices(signal: signal, capital: capital)
        } catch {
            print("从云端拉取信号失败: \(error), 尝试本地缓存或计算")
            
            // 2. Fallback: 尝试本地缓存
            if let cached = UserDefaults.standard.data(forKey: "cached_signal"),
               let signal = try? JSONDecoder().decode(StrategySignal.self, from: cached) {
                print("使用本地缓存信号")
                latestSignal = signal
                classified = store.classifyHoldings(signal: signal)
                updateAdvices(signal: signal, capital: capital)
            } else {
                // 3. Fallback: 本地计算（最后手段）
                print("本地缓存也失败，执行本地计算")
                do {
                    let signal = try await strategy.computeSignal(totalCapital: capital)
                    latestSignal = signal
                    classified = store.classifyHoldings(signal: signal)
                    updateAdvices(signal: signal, capital: capital)
                } catch {
                    signalError = "无法获取策略信号: \(error.localizedDescription)"
                    classified = store.classifyHoldings(signal: nil)
                }
            }
        }

        isLoadingSignal = false
    }
    
    private func updateAdvices(signal: StrategySignal, capital: Double) {
        let adviceList = SevenStarStrategy.compareHoldings(
            current: store.portfolio.holdings,
            signal: signal,
            totalCapital: capital
        )
        var map: [String: HoldingAction] = [:]
        var buys: [String] = []
        for advice in adviceList {
            map[advice.stockName] = advice.action
            if advice.action == .buy && !store.portfolio.holdings.contains(where: { $0.stockName == advice.stockName }) {
                buys.append(advice.stockName)
            }
        }
        advices = map
        buyAdviceNames = buys
    }
    
    private func setupNotifications() async {
        // 请求通知权限
        guard await notificationManager.requestAuthorization() else {
            print("用户拒绝通知权限")
            return
        }
        
        // 注册每日 14:00 信号提醒
        await notificationManager.scheduleDailySignalReminder()
    }

    // MARK: - Helpers

    private func formatSignalDate(_ dateStr: String) -> String {
        // "20260219" → "2026/02/19"
        guard dateStr.count == 8 else { return dateStr }
        let y = dateStr.prefix(4)
        let m = dateStr.dropFirst(4).prefix(2)
        let d = dateStr.dropFirst(6)
        return "\(y)/\(m)/\(d)"
    }

    private func formatCurrency(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        return fmt.string(from: NSNumber(value: value)) ?? "0.00"
    }
}

// MARK: - A 股语义配色

extension Color {
    /// A 股红涨 / 买入
    static let stockUp = Color(red: 0.91, green: 0.22, blue: 0.22)
    /// A 股绿跌 / 卖出
    static let stockDown = Color(red: 0.12, green: 0.72, blue: 0.35)
}

// MARK: - HoldingAction 颜色扩展

extension HoldingAction {
    var displayColor: Color {
        switch self {
        case .hold: return .gray
        case .buy: return .stockUp
        case .sell: return .stockDown
        case .add: return .orange
        case .reduce: return .blue
        case .match: return .secondary
        }
    }
}

// MARK: - 操作建议胶囊标签

struct HoldingActionTag: View {
    let action: HoldingAction

    var body: some View {
        Text(action.rawValue)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(action.displayColor.opacity(0.12))
            )
            .foregroundStyle(action.displayColor)
    }
}

// MARK: - 单只持仓行

struct HoldingRow: View {
    let holding: Holding
    var action: HoldingAction?
    var badge: String? = nil
    var strategyShares: Int? = nil
    var freePlayShares: Int? = nil

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(holding.stockName)
                        .font(.subheadline.bold())
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9).bold())
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.1))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 6) {
                    Text("\(holding.shares) 股")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let s = strategyShares, let f = freePlayShares, f > 0 {
                        Text("策略\(s) · 自选\(f)")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("¥\(String(format: "%.3f", holding.costPrice))")
                    .font(.subheadline.monospacedDigit())
                Text("¥\(String(format: "%.0f", holding.totalCost))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let action {
                HoldingActionTag(action: action)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
