# Trading 助手模块

A股量化交易助手，每日操作一次，轻松风格。

## 📋 功能概览

### Phase 1 - 仓位管理
- ✅ **持仓记录**：股票代码、名称、股数、成本价
- ✅ **OCR 导入**：拍照/相册导入东方财富持仓截图，自动识别
- ✅ **收盘价获取**：东方财富 API，自动获取A股收盘价
- ✅ **每日快照**：记录每日持仓状态
- ✅ **iCloud 同步**：数据同步 + 本地备份

### 未来规划
- [ ] 量化策略信号
- [ ] 每日操作建议
- [ ] 收益曲线图表
- [ ] 交易记录
- [ ] 多账户支持

## 🏗️ 架构

### 数据模型
- `Holding` — 单只持仓（代码、名称、股数、成本价）
- `HoldingSnapshot` — 快照中的持仓（含收盘价）
- `DailySnapshot` — 每日快照（所有持仓 + 总资产）
- `Portfolio` — 投资组合（持仓 + 快照 + 资金）
- `OCRHoldingResult` — OCR 识别结果

### 核心组件
- `TradingStore` — 数据管理（@Observable），iCloud 持久化
- `OCRService` — VisionKit OCR，适配东方财富截图格式
- `StockAPI`（内置于 Store）— 东方财富收盘价 API

### 视图组件（待建）
- `TradingHomeView` — 首页/仓位总览
- `ScanImportView` — OCR 扫描导入
- `PortfolioView` — 持仓详情
- `SnapshotHistoryView` — 历史快照

## 💾 存储
- iCloud Documents/trading_data.json + 本地备份
- 与 Travel 模块独立，同一套 iCloud 容器

## 🔗 行情 API
- 东方财富 pushAPI（免费，无需 key）
- 沪市：`1.XXXXXX`，深市：`0.XXXXXX`
- 返回收盘价 f43（×100 整数）

## 📱 OCR 适配
- 当前：东方财富 App 持仓截图
- 识别：VNRecognizeTextRequest，中英文混合
- 解析：按行分组 → 匹配股票代码 → 提取数字

---

**版本**：0.1  
**状态**：🚧 开发中  
**最后更新**：2026-02-17
