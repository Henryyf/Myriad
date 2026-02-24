//
//  TradingRouter.swift
//  Myriad
//
//  Created by 洪嘉禺 on 2/17/26.
//

import Foundation

enum TradingRoute: Hashable {
    case portfolio          // 仓位总览
    case holdingDetail(UUID) // 单只持仓详情
    case snapshot(String)    // 某日快照，参数为日期字符串
    case scanImport         // OCR 扫描导入
    case settings           // 策略设置
    case announcements      // 公告
}
