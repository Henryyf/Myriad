//
//  NotificationManager.swift
//  Myriad
//
//  Created by Main on 2/22/26.
//

import Foundation
import UserNotifications
import Observation

@MainActor
@Observable
class NotificationManager {
    
    var isAuthorized = false
    
    // 检查通知权限
    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    // 请求通知权限
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            print("通知权限请求失败: \(error)")
            return false
        }
    }
    
    // 注册每日信号提醒（北京时间 14:00）
    func scheduleDailySignalReminder() async {
        // 先确保有权限
        guard isAuthorized else {
            print("无通知权限，跳过注册")
            return
        }
        
        let center = UNUserNotificationCenter.current()
        
        // 移除旧的提醒（避免重复）
        center.removePendingNotificationRequests(withIdentifiers: ["daily-signal-reminder"])
        
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = "七星信号提醒"
        content.body = "今日策略信号已就绪，点击查看调仓建议"
        content.sound = .default
        content.badge = 1
        
        // 设置每天北京时间 14:00 触发
        var beijingComponents = DateComponents()
        beijingComponents.calendar = Calendar(identifier: .gregorian)
        beijingComponents.timeZone = TimeZone(identifier: "Asia/Shanghai")
        beijingComponents.hour = 14
        beijingComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: beijingComponents,
            repeats: true
        )
        
        print("📍 通知设置为北京时间 14:00（不随设备时区变化）")
        
        let request = UNNotificationRequest(
            identifier: "daily-signal-reminder",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("✅ 每日 14:00 信号提醒已注册")
        } catch {
            print("❌ 通知注册失败: \(error)")
        }
    }
    
    // 取消所有通知
    func cancelAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        print("已取消所有通知")
    }
}
