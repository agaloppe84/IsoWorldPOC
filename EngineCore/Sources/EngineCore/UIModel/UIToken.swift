public struct UIStyleColor: Equatable, Hashable, Codable, Sendable {
    public let red: Float
    public let green: Float
    public let blue: Float
    public let alpha: Float

    public init(
        red: Float,
        green: Float,
        blue: Float,
        alpha: Float = 1
    ) {
        self.red = Self.clamped01(red)
        self.green = Self.clamped01(green)
        self.blue = Self.clamped01(blue)
        self.alpha = Self.clamped01(alpha)
    }

    public init(_ biomeColor: BiomeColor, alpha: Float = 1) {
        self.init(
            red: biomeColor.red,
            green: biomeColor.green,
            blue: biomeColor.blue,
            alpha: alpha
        )
    }

    public func mixed(with other: UIStyleColor, amount: Float) -> UIStyleColor {
        let t = Self.clamped01(amount)

        return UIStyleColor(
            red: red + (other.red - red) * t,
            green: green + (other.green - green) * t,
            blue: blue + (other.blue - blue) * t,
            alpha: alpha + (other.alpha - alpha) * t
        )
    }

    public func withAlpha(_ alpha: Float) -> UIStyleColor {
        UIStyleColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value.isFinite ? value : 0, 0), 1)
    }
}

public struct UIThemePalette: Equatable, Hashable, Codable, Sendable {
    public let surface: UIStyleColor
    public let surfaceAlt: UIStyleColor
    public let outline: UIStyleColor
    public let textPrimary: UIStyleColor
    public let textSecondary: UIStyleColor
    public let accent: UIStyleColor
    public let danger: UIStyleColor
    public let warning: UIStyleColor
    public let success: UIStyleColor

    public init(
        surface: UIStyleColor,
        surfaceAlt: UIStyleColor,
        outline: UIStyleColor,
        textPrimary: UIStyleColor,
        textSecondary: UIStyleColor,
        accent: UIStyleColor,
        danger: UIStyleColor,
        warning: UIStyleColor,
        success: UIStyleColor
    ) {
        self.surface = surface
        self.surfaceAlt = surfaceAlt
        self.outline = outline
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.accent = accent
        self.danger = danger
        self.warning = warning
        self.success = success
    }

    public func modulated(by biome: Biome, amount: Float) -> UIThemePalette {
        let tint = UIStyleColor(biome.previewColor)
        let modulation = min(max(amount, 0), 1)

        return UIThemePalette(
            surface: surface.mixed(with: tint.withAlpha(surface.alpha), amount: modulation * 0.10),
            surfaceAlt: surfaceAlt.mixed(with: tint.withAlpha(surfaceAlt.alpha), amount: modulation * 0.14),
            outline: outline.mixed(with: tint.withAlpha(outline.alpha), amount: modulation * 0.18),
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            accent: accent.mixed(with: tint, amount: modulation * 0.30),
            danger: danger,
            warning: warning,
            success: success.mixed(with: tint, amount: modulation * 0.10)
        )
    }
}

public struct UITypographyTokens: Equatable, Hashable, Codable, Sendable {
    public let labelPixelHeight: Float
    public let titlePixelHeight: Float
    public let digitPixelHeight: Float

    public init(
        labelPixelHeight: Float,
        titlePixelHeight: Float,
        digitPixelHeight: Float
    ) {
        self.labelPixelHeight = max(labelPixelHeight, 6)
        self.titlePixelHeight = max(titlePixelHeight, self.labelPixelHeight)
        self.digitPixelHeight = max(digitPixelHeight, 6)
    }
}

public struct UIShapeTokens: Equatable, Hashable, Codable, Sendable {
    public let cornerRadius: Float
    public let strokeWidth: Float
    public let ornamentLevel: Float

    public init(
        cornerRadius: Float,
        strokeWidth: Float,
        ornamentLevel: Float
    ) {
        self.cornerRadius = max(cornerRadius, 0)
        self.strokeWidth = max(strokeWidth, 0)
        self.ornamentLevel = min(max(ornamentLevel, 0), 1)
    }
}

public struct UIFrameRect: Equatable, Hashable, Codable, Sendable {
    public let x: Float
    public let y: Float
    public let width: Float
    public let height: Float

    public init(x: Float, y: Float, width: Float, height: Float) {
        self.x = x.isFinite ? x : 0
        self.y = y.isFinite ? y : 0
        self.width = max(width.isFinite ? width : 0, 0)
        self.height = max(height.isFinite ? height : 0, 0)
    }
}
