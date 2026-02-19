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
    @State private var buyAdviceNames: [String] = []  // 需要买入但当前未持有的
    @State private var signalError: String?
    @State private var isLoadingSignal = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 今日操作信号灯（最重要的信息，3秒决策）
                    signalLightCard

                    // 今日未更新提醒
                    if !store.isUpdatedToday {
                        updateReminder
                    }

                    // 资产汇总
                    summaryCard

                    // 策略仓
                    strategySection

                    // 自选仓
                    freePlaySection

                    // 需要买入的（当前没有持仓的）
                    if !buyAdviceNames.isEmpty {
                        buySection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer(minLength: 110)
            }
            .navigationTitle("Trading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: TradingRoute.settings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15, weight: .medium))
                    }
                }
            }
            .sheet(isPresented: $showingScanSheet) {
                ScanImportSheet(store: store)
            }
            .task {
                await fetchSignal()
            }

            floatingAddButton
        }
    }

    // MARK: - 今日信号灯（核心 UX：3秒知道该干嘛）

    private var signalLightCard: some View {
        VStack(spacing: 12) {
            if isLoadingSignal {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在获取今日信号...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
            } else if let signal = latestSignal {
                // 有信号
                VStack(spacing: 10) {
                    // 信号日期
                    HStack {
                        Text("📡 \(signal.date) 信号")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(signalStatusText(signal))
                            .font(.caption.bold())
                            .foregroundStyle(signalStatusColor(signal))
                    }

                    // 操作摘要——用户最关心的
                    if hasActions {
                        VStack(spacing: 6) {
                            ForEach(actionSummary, id: \.self) { line in
                                HStack(spacing: 8) {
                                    Text(line.icon)
                                        .font(.title3)
                                    Text(line.text)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(line.color)
                                    Spacer()
                                }
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text("⚪")
                                .font(.title3)
                            Text("今日持仓不变，继续持有")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
                .padding(16)
            } else if let error = signalError {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(.orange)
                    Text("信号获取失败")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                    Spacer()
                }
                .padding(16)
            } else {
                HStack(spacing: 8) {
                    Text("⏳")
                        .font(.title3)
                    Text("等待今日信号")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    // MARK: - 操作摘要

    private struct ActionLine: Hashable {
        let icon: String
        let text: String
        let color: Color
    }

    private var hasActions: Bool {
        !buyAdviceNames.isEmpty || advices.values.contains(where: { $0 == .sell || $0 == .buy || $0 == .add || $0 == .reduce })
    }

    private var actionSummary: [ActionLine] {
        var lines: [ActionLine] = []

        // 卖出
        let sells = advices.filter { $0.value == .sell }
        for (name, _) in sells {
            lines.append(ActionLine(icon: "🔴", text: "卖出 \(name)", color: .green))
        }

        // 买入
        for name in buyAdviceNames {
            lines.append(ActionLine(icon: "🟢", text: "买入 \(name)", color: .red))
        }

        // 加仓
        let adds = advices.filter { $0.value == .add }
        for (name, _) in adds {
            lines.append(ActionLine(icon: "🟡", text: "补仓 \(name)", color: .orange))
        }

        // 减仓
        let reduces = advices.filter { $0.value == .reduce }
        for (name, _) in reduces {
            lines.append(ActionLine(icon: "🔵", text: "减仓 \(name)", color: .blue))
        }

        return lines
    }

    // MARK: - 今日未更新提醒

    private var updateReminder: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
            Text("今日尚未更新持仓，点击下方扫描按钮导入")
                .font(.caption.bold())
                .foregroundStyle(.orange)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }

    // MARK: - 资产汇总卡片

    private var summaryCard: some View {
        VStack(spacing: 14) {
            HStack {
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
                        .font(.headline.monospacedDigit())
                }
            }

            Divider()

            // 三仓分配可视化
            HStack(spacing: 0) {
                let config = store.portfolio.strategyConfig
                let breakdown = store.portfolioBreakdown(classified: classified)

                VStack(spacing: 4) {
                    Text("📊 策略仓")
                        .font(.caption2)
                    Text("\(Int(config.strategyPercent * 100))%")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.blue)
                    Text("¥\(formatCurrency(breakdown.strategyValue))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("🎮 自选仓")
                        .font(.caption2)
                    Text("\(Int(config.freePlayPercent * 100))%")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.purple)
                    Text("¥\(formatCurrency(breakdown.freePlayValue))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("💵 现金")
                        .font(.caption2)
                    Text("\(Int(config.cashPercent * 100))%")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.gray)
                    Text("¥\(formatCurrency(store.portfolio.cashBalance))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    // MARK: - 策略仓

    private var strategySection: some View {
        let strategyHoldings = classified.filter { $0.category == .strategy || $0.category == .mixed }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("📊 策略仓")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(strategyHoldings.count) 只")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if strategyHoldings.isEmpty {
                Text("暂无策略持仓")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
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
        }
    }

    // MARK: - 自选仓

    private var freePlaySection: some View {
        let freePlayHoldings = classified.filter { $0.category == .freePlay }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("🎮 自选仓")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(freePlayHoldings.count) 只")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if freePlayHoldings.isEmpty && store.portfolio.holdings.isEmpty {
                emptyState
            } else if freePlayHoldings.isEmpty {
                Text("全部持仓都在策略仓中 👍")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ForEach(freePlayHoldings) { ch in
                    HoldingRow(holding: ch.holding, action: nil)
                }
            }
        }
    }

    // MARK: - 策略推荐买入

    private var buySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🟢 策略推荐买入")
                .font(.subheadline.bold())

            ForEach(buyAdviceNames, id: \.self) { name in
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.headline)
                        Text("当前未持有")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HoldingActionTag(action: .buy)
                }
                .padding(14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("暂无持仓记录")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("点击下方扫描按钮，拍东方财富持仓截图导入")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - 底部扫描按钮

    private var floatingAddButton: some View {
        Button {
            showingScanSheet = true
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - 信号获取

    private func fetchSignal() async {
        isLoadingSignal = true
        signalError = nil

        let capital = store.portfolio.strategyBudget
        let baseURL = UserDefaults.standard.string(forKey: "trading_worker_url") ?? TradingSignalService.defaultBaseURL
        let apiKey = UserDefaults.standard.string(forKey: "trading_api_key") ?? TradingSignalService.defaultAPIKey

        do {
            let signal = try await TradingSignalService.fetchLatestSignal(
                baseURL: baseURL,
                apiKey: apiKey,
                totalCapital: capital > 0 ? capital : nil
            )
            latestSignal = signal

            // 分类持仓
            classified = store.classifyHoldings(signal: signal)

            // 生成操作建议
            let adviceList = store.compareWithSignal(signal)
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
        } catch {
            signalError = error.localizedDescription
            classified = store.classifyHoldings(signal: nil)
        }

        isLoadingSignal = false
    }

    // MARK: - Helpers

    private func signalStatusText(_ signal: StrategySignal) -> String {
        switch signal.status {
        case "signal": return "有调仓信号"
        case "defensive": return "防御模式"
        default: return signal.status
        }
    }

    private func signalStatusColor(_ signal: StrategySignal) -> Color {
        switch signal.status {
        case "signal": return .red
        case "defensive": return .blue
        default: return .secondary
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        return fmt.string(from: NSNumber(value: value)) ?? "0.00"
    }
}

// MARK: - 操作建议胶囊标签

struct HoldingActionTag: View {
    let action: HoldingAction

    var body: some View {
        Text(action.rawValue)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tagBackgroundGradient)
            )
            .foregroundStyle(tagForeground)
            .overlay(
                Capsule()
                    .stroke(tagForeground.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: tagForeground.opacity(0.15), radius: 4, x: 0, y: 2)
    }

    private var tagForeground: Color {
        switch action {
        case .hold: return .gray
        case .buy: return .red
        case .sell: return .green
        case .add: return .orange
        case .reduce: return .blue
        case .match: return .green
        }
    }

    private var tagBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [tagForeground.opacity(0.2), tagForeground.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(holding.stockName)
                        .font(.headline)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9).bold())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Text("\(holding.shares) 股")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // 混合仓位详情
                    if let s = strategyShares, let f = freePlayShares, f > 0 {
                        Text("策略\(s) / 自选\(f)")
                            .font(.system(size: 10))
                            .foregroundStyle(.purple)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("¥\(formatPrice(holding.costPrice))")
                    .font(.subheadline.monospacedDigit())
                Text("¥\(formatPrice(holding.totalCost))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let action {
                HoldingActionTag(action: action)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func formatPrice(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}
