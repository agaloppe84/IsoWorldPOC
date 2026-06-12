public struct UITheme: Equatable, Hashable, Codable, Sendable {
    public let id: UIThemeID
    public let palette: UIThemePalette
    public let typography: UITypographyTokens
    public let shapes: UIShapeTokens

    public init(
        id: UIThemeID,
        palette: UIThemePalette,
        typography: UITypographyTokens,
        shapes: UIShapeTokens
    ) {
        self.id = id
        self.palette = palette
        self.typography = typography
        self.shapes = shapes
    }

    public static func resolved(
        dna: UIWorldDNA,
        biome: Biome
    ) -> UITheme {
        let base = definition(for: dna.themeID)

        return UITheme(
            id: base.id,
            palette: base.palette.modulated(by: biome, amount: dna.biomeReactivity),
            typography: base.typography,
            shapes: base.shapes
        )
    }

    public static func definition(for id: UIThemeID) -> UITheme {
        switch id {
        case .neutral:
            UITheme(
                id: .neutral,
                palette: UIThemePalette(
                    surface: UIStyleColor(red: 0.05, green: 0.07, blue: 0.08, alpha: 0.70),
                    surfaceAlt: UIStyleColor(red: 0.10, green: 0.13, blue: 0.14, alpha: 0.78),
                    outline: UIStyleColor(red: 0.55, green: 0.68, blue: 0.65, alpha: 0.55),
                    textPrimary: UIStyleColor(red: 0.94, green: 0.97, blue: 0.92),
                    textSecondary: UIStyleColor(red: 0.72, green: 0.79, blue: 0.76),
                    accent: UIStyleColor(red: 0.42, green: 0.84, blue: 0.68),
                    danger: UIStyleColor(red: 0.92, green: 0.24, blue: 0.18),
                    warning: UIStyleColor(red: 0.95, green: 0.70, blue: 0.18),
                    success: UIStyleColor(red: 0.34, green: 0.80, blue: 0.36)
                ),
                typography: UITypographyTokens(labelPixelHeight: 9, titlePixelHeight: 12, digitPixelHeight: 10),
                shapes: UIShapeTokens(cornerRadius: 5, strokeWidth: 1, ornamentLevel: 0.12)
            )
        case .parchment:
            UITheme(
                id: .parchment,
                palette: UIThemePalette(
                    surface: UIStyleColor(red: 0.36, green: 0.27, blue: 0.16, alpha: 0.72),
                    surfaceAlt: UIStyleColor(red: 0.53, green: 0.42, blue: 0.26, alpha: 0.76),
                    outline: UIStyleColor(red: 0.86, green: 0.68, blue: 0.34, alpha: 0.62),
                    textPrimary: UIStyleColor(red: 0.98, green: 0.88, blue: 0.62),
                    textSecondary: UIStyleColor(red: 0.82, green: 0.70, blue: 0.48),
                    accent: UIStyleColor(red: 0.91, green: 0.56, blue: 0.22),
                    danger: UIStyleColor(red: 0.78, green: 0.18, blue: 0.12),
                    warning: UIStyleColor(red: 0.96, green: 0.72, blue: 0.22),
                    success: UIStyleColor(red: 0.38, green: 0.70, blue: 0.34)
                ),
                typography: UITypographyTokens(labelPixelHeight: 9, titlePixelHeight: 12, digitPixelHeight: 10),
                shapes: UIShapeTokens(cornerRadius: 2, strokeWidth: 1.5, ornamentLevel: 0.46)
            )
        case .sciFi:
            UITheme(
                id: .sciFi,
                palette: UIThemePalette(
                    surface: UIStyleColor(red: 0.02, green: 0.05, blue: 0.09, alpha: 0.58),
                    surfaceAlt: UIStyleColor(red: 0.04, green: 0.12, blue: 0.18, alpha: 0.68),
                    outline: UIStyleColor(red: 0.20, green: 0.88, blue: 1.00, alpha: 0.62),
                    textPrimary: UIStyleColor(red: 0.86, green: 0.98, blue: 1.00),
                    textSecondary: UIStyleColor(red: 0.52, green: 0.78, blue: 0.88),
                    accent: UIStyleColor(red: 0.13, green: 0.74, blue: 1.00),
                    danger: UIStyleColor(red: 1.00, green: 0.18, blue: 0.34),
                    warning: UIStyleColor(red: 1.00, green: 0.82, blue: 0.18),
                    success: UIStyleColor(red: 0.18, green: 0.94, blue: 0.62)
                ),
                typography: UITypographyTokens(labelPixelHeight: 8, titlePixelHeight: 11, digitPixelHeight: 10),
                shapes: UIShapeTokens(cornerRadius: 1, strokeWidth: 1, ornamentLevel: 0.30)
            )
        }
    }
}
