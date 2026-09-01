/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * 统一 3D 可爱图标层（CuteIcon）。
 * 所有功能图标均使用 AI 生成的 claymorphism 3D 渲染 PNG（Assets.xcassets/cute-*.imageset），
 * 保持薄荷绿/薰衣草主题色、一致大圆角、柔光的统一大厂风格。
 * 若某图标尚未生成，则回退到同名 SF Symbol，保证不缺图。
 */

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

enum CuteIconName: String, CaseIterable {
    // 天气
    case sun = "cute-sun"
    case cloud = "cute-cloud"
    case rain = "cute-rain"
    case snow = "cute-snow"
    case thunder = "cute-thunder"
    case moon = "cute-moon"
    case cloudy = "cute-cloudy"
    case fog = "cute-fog"
    // 媒体 / 系统状态 / 通知 / 操作
    case music = "cute-music"
    case bell = "cute-bell"
    case battery = "cute-battery"
    case wifi = "cute-wifi"
    case gear = "cute-gear"
    case check = "cute-check"
    case x = "cute-x"
    case calendar = "cute-calendar"
    // 功能性
    case arrowUp = "cute-arrow-up"
    case arrowDown = "cute-arrow-down"
    case arrowLeft = "cute-arrow-left"
    case arrowRight = "cute-arrow-right"
    case camera = "cute-camera"
    case person = "cute-person"
    case plus = "cute-plus"
    case minus = "cute-minus"
    case ellipsis = "cute-ellipsis"
    case magnifier = "cute-magnifier"
    case trash = "cute-trash"
    case heart = "cute-heart"
    case lock = "cute-lock"
    case star = "cute-star"

    /// SF Symbol 回退名（仅当 3D 资源缺失时使用）
    var fallbackSF: String {
        switch self {
        case .sun: return "sun.max.fill"
        case .cloud: return "cloud.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "cloud.snow.fill"
        case .thunder: return "cloud.bolt.fill"
        case .moon: return "moon.fill"
        case .cloudy: return "cloud.sun.fill"
        case .fog: return "cloud.fog.fill"
        case .music: return "music.note"
        case .bell: return "bell.fill"
        case .battery: return "battery.100percent"
        case .wifi: return "wifi"
        case .gear: return "gearshape.fill"
        case .check: return "checkmark.circle.fill"
        case .x: return "xmark.circle.fill"
        case .calendar: return "calendar"
        case .arrowUp: return "arrow.up"
        case .arrowDown: return "arrow.down"
        case .arrowLeft: return "arrow.left"
        case .arrowRight: return "arrow.right"
        case .camera: return "camera.fill"
        case .person: return "person.fill"
        case .plus: return "plus"
        case .minus: return "minus"
        case .ellipsis: return "ellipsis"
        case .magnifier: return "magnifyingglass"
        case .trash: return "trash"
        case .heart: return "heart"
        case .lock: return "lock"
        case .star: return "star"
        }
    }
}

struct CuteIcon: View {
    let name: CuteIconName
    var size: CGFloat = 24
    var tint: Color = .white

    var body: some View {
        Image(name.rawValue)
            .resizable()
            .renderingMode(.original)
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel(Text(name.rawValue))
    }
}

extension Image {
    #if canImport(AppKit)
    /// Return raster cute assets with a small natural point size.
    ///
    /// `Image.cuteSymbol` is intentionally shaped like `Image(systemName:)`, so
    /// many call sites size it with `.font(...)` or forget a frame entirely.
    /// Asset-catalog PNGs keep their natural 1024×1024 size in that path, which
    /// can explode inside compact controls. Use a copied NSImage so the shared
    /// cache is not mutated, and give it a safe intrinsic size; dedicated runtime
    /// widgets that need precise sizing should use `AtollCuteIcon`/`CuteIcon`.
    private static func boundedCuteRaster(_ name: String, pointSize: CGFloat = 18) -> Image? {
        guard let source = AtollCuteIconAssets.image(named: name) ?? NSImage(named: name) else {
            return nil
        }
        let image = (source.copy() as? NSImage) ?? source
        image.size = NSSize(width: pointSize, height: pointSize)
        return Image(nsImage: image).renderingMode(.original)
    }
    #endif

    /// 用统一的 3D 可爱图标（回退 SF Symbol）
    static func cute(_ name: CuteIconName) -> Image {
        #if canImport(AppKit)
        if let image = boundedCuteRaster(name.rawValue) { return image }
        #endif
        return Image(systemName: name.fallbackSF)
    }

    /// 直接用 SF Symbol 名查询统一 3D 可爱图标（自动回退 SF Symbol）
    static func cuteSymbol(_ sfName: String) -> Image {
        if let asset = AtollCuteIconAssets.assetName(for: sfName),
           let image = boundedCuteRaster(asset) {
            return image
        }
        return Image(systemName: sfName.isEmpty ? "sparkles" : sfName)
    }
}
