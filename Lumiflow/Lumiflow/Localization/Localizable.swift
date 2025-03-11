import Foundation
import SwiftUI

// 定义支持的语言
enum AppLanguage: String, CaseIterable {
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"
    
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .english: return "English"
        case .chinese: return "中文"
        }
    }
}

// 本地化字符串管理器
struct LocalizationManager {
    static var currentLanguage: AppLanguage = .system
    
    // 中英文字符串映射表
    static let translations: [String: [AppLanguage: String]] = [
        "select_color": [
            .english: "Select Color",
            .chinese: "选择颜色"
        ],
        "close": [
            .english: "Close",
            .chinese: "关闭"
        ],
        "select_light_color": [
            .english: "Select Light Color",
            .chinese: "选择补光颜色"
        ],
        "photo_saved": [
            .english: "Photo saved to album",
            .chinese: "照片已保存到相册"
        ],
        "photo_save_failed": [
            .english: "Failed to save photo",
            .chinese: "保存照片失败"
        ],
        "operation_guide": [
            .english: "Tap to capture • Pinch to zoom • Drag to move",
            .chinese: "点击预览框拍照 • 双指缩放 • 拖动调整位置"
        ],
        "camera_permission_denied": [
            .english: "Camera permission denied",
            .chinese: "相机权限被拒绝"
        ],
        "camera_not_ready": [
            .english: "Camera not ready",
            .chinese: "相机未准备好"
        ],
        "camera_setup_error": [
            .english: "Camera setup error",
            .chinese: "相机设置出错"
        ],
        "front_camera_not_found": [
            .english: "Front camera not found",
            .chinese: "无法找到前置摄像头"
        ],
        "cannot_add_camera_input": [
            .english: "Cannot add camera input",
            .chinese: "无法添加摄像头输入"
        ],
        "cannot_add_photo_output": [
            .english: "Cannot add photo output",
            .chinese: "无法添加照片输出"
        ],
        "retry": [
            .english: "Retry",
            .chinese: "重试"
        ]
    ]
    
    static func localizedString(_ key: String) -> String {
        let deviceLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        let isChineseDevice = deviceLanguage.hasPrefix("zh")
        
        // 确定要使用的语言
        let targetLanguage: AppLanguage
        switch currentLanguage {
        case .system:
            targetLanguage = isChineseDevice ? .chinese : .english
        default:
            targetLanguage = currentLanguage
        }
        
        // 获取翻译
        if let translations = translations[key],
           let translatedString = translations[targetLanguage] {
            return translatedString
        }
        
        // 回退到英文或键值
        return translations[key]?[.english] ?? key
    }
}

// 扩展String以简化本地化
extension String {
    var localized: String {
        return LocalizationManager.localizedString(self)
    }
}

// 本地化文本组件
struct LocalizedText: View {
    let key: String
    let font: Font?
    let color: Color?
    
    init(_ key: String, font: Font? = nil, color: Color? = nil) {
        self.key = key
        self.font = font
        self.color = color
    }
    
    var body: some View {
        Text(key.localized)
            .font(font)
            .foregroundColor(color)
    }
} 