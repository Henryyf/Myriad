# TravelMapView Phase 1 使用指南

## 🎯 已实现功能

### 1. 页面结构
- ✅ 顶部标题区：显示"旅行地图"和已解锁国家数
- ✅ 状态筛选：Segment控件（已完成/旅行中/计划中/全部）
- ✅ 地图主体：Apple MapKit世界地图
- ✅ 国家徽章Marker：圆形材质+Emoji国旗+状态颜色
- ✅ 底部卡片：点击marker后显示国家详情

### 2. 数据聚合
- ✅ 自动从trips标题推断国家代码
- ✅ 按国家聚合旅行数据
- ✅ 支持状态筛选
- ✅ 统计每个国家的旅行次数和最近旅行日期

### 3. 交互设计
- ✅ 点击marker选中国家
- ✅ 底部卡片动画弹出
- ✅ CTA按钮跳转到旅行列表
- ✅ 关闭按钮清除选中状态

## 📊 数据流程

```
TravelStore.trips
    ↓
推断国家代码（基于城市名称）
    ↓
按国家分组 + 状态筛选
    ↓
生成 CountryFootprint[]
    ↓
在地图上显示Marker
```

## 🎨 视觉设计

### Marker颜色（柔和色调）
- 已完成：雾蓝（blue.opacity(0.7)）
- 旅行中：薄荷（green.opacity(0.7)）
- 计划中：蜜桃（orange.opacity(0.7)）

### 交互状态
- 未选中：48x48，2px边框，4pt阴影
- 选中：60x60，3px边框，8pt阴影，弹性动画

### 底部卡片
- 材质：.ultraThinMaterial
- 圆角：22pt
- 阴影：(0, -4)，8% opacity，16pt radius

## 🗺️ 支持的国家（Phase 1）

当前支持10个国家，可通过城市名称自动识别：

| 国家 | 代码 | 识别关键词 | Emoji |
|------|------|-----------|-------|
| 日本 | JP | Tokyo, Osaka, Kyoto, 東京, 大阪, 京都 | 🇯🇵 |
| 加拿大 | CA | Vancouver, Toronto, Montreal, 温哥华 | 🇨🇦 |
| 美国 | US | New York, Los Angeles, San Francisco | 🇺🇸 |
| 英国 | GB | London, 伦敦 | 🇬🇧 |
| 法国 | FR | Paris, 巴黎 | 🇫🇷 |
| 中国 | CN | Beijing, Shanghai, 北京, 上海 | 🇨🇳 |
| 韩国 | KR | Seoul, 首尔 | 🇰🇷 |
| 泰国 | TH | Bangkok, 曼谷 | 🇹🇭 |
| 意大利 | IT | Rome, Milan, 罗马, 米兰 | 🇮🇹 |
| 澳大利亚 | AU | Sydney, Melbourne, 悉尼 | 🇦🇺 |

## 🔧 如何扩展

### 添加新国家

1. 在 `CountryInfoProvider.countries` 中添加：
```swift
"XX": CountryInfo(
    code: "XX",
    name: "国家名",
    flagEmoji: "🇽🇽",
    coordinate: CLLocationCoordinate2D(latitude: xx.xx, longitude: xx.xx),
    description: "一句话介绍"
)
```

2. 在 `inferCountryCode()` 中添加识别规则：
```swift
if titleLower.contains("city") || titleLower.contains("城市名") {
    return "XX"
}
```

### Phase 2 可扩展功能

- [ ] 从旅行详情中手动选择国家
- [ ] 点击国家卡片CTA时，过滤显示该国家的旅行
- [ ] 添加国家搜索功能
- [ ] 支持多国旅行（一个Trip对应多个国家）
- [ ] 照片墙：在国家卡片中显示该国家的照片集
- [ ] 国家成就系统：洲际徽章、大满贯等
- [ ] 轨迹连线：按时间顺序连接国家

## 🐛 已知限制

1. **国家识别**：仅基于城市名称关键词，不够精确
   - 解决方案：未来可添加手动选择国家功能
   
2. **同一国家多个城市**：如果一个国家有多个旅行，只显示一个marker
   - 这是设计意图：最小单位是国家
   
3. **未识别的城市**：不会显示在地图上
   - 解决方案：扩展 `inferCountryCode()` 的关键词列表

## 📱 测试数据

使用mock数据测试：
- Tokyo → 应显示 🇯🇵 日本
- Osaka → 应显示 🇯🇵 日本（与Tokyo合并）
- Vancouver → 应显示 🇨🇦 加拿大

切换状态筛选，marker应该动态更新。

## 💡 使用建议

1. 创建旅行时，标题使用英文或中文城市名称
2. 点击地图marker查看国家详情
3. 使用状态筛选器查看不同阶段的旅行足迹
4. 底部卡片提供快速跳转到旅行列表

---

**Phase 1 完成 ✅** - MVP可用，架构可扩展
