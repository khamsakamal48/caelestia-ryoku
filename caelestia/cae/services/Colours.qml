pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import shell.services as R

// Adapter: Caelestia's Colours interface over Ryoku's live palette. Ryoku owns
// the colour scheme (named theme or the wallpaper's Matugen roles), so this
// reads it instead of Caelestia's scheme.json. Roles Ryoku lacks keep
// Caelestia's defaults. layer()/on()/tPalette are Caelestia's own logic.
Singleton {
    id: root

    readonly property bool light: R.Theme.relLum(R.Theme.surface) > 0.4
    readonly property M3Palette palette: M3Palette {}
    readonly property M3Palette current: palette
    readonly property M3TPalette tPalette: M3TPalette {}
    readonly property Transparency transparency: Transparency {}
    readonly property real wallLuminance: R.Theme.relLum(R.Theme.surface)

    // Roles Ryoku's palette doesn't carry borrow the nearest one it does, so
    // nothing falls back to Caelestia's pink defaults against a Ryoku theme.
    readonly property var aliases: ({
        background: "surface", onBackground: "onSurface",
        surfaceDim: "surface", surfaceBright: "surfaceContainerHighest",
        inversePrimary: "primaryContainer",
        primaryPaletteKeyColor: "primary", secondaryPaletteKeyColor: "secondary",
        tertiaryPaletteKeyColor: "tertiary", neutralPaletteKeyColor: "outline",
        neutral_variantPaletteKeyColor: "outlineVariant",
        primaryFixed: "primary", primaryFixedDim: "primary",
        onPrimaryFixed: "onPrimary", onPrimaryFixedVariant: "onPrimaryContainer",
        secondaryFixed: "secondary", secondaryFixedDim: "secondary",
        onSecondaryFixed: "onSecondary", onSecondaryFixedVariant: "onSecondaryContainer",
        tertiaryFixed: "tertiary", tertiaryFixedDim: "tertiary",
        onTertiaryFixed: "onTertiary", onTertiaryFixedVariant: "onTertiaryContainer"
    })

    // Named theme, then wallpaper roles, then Ryoku's Theme, then an alias, then Caelestia's default.
    function role(key: string, fallback: color): color {
        const named = R.Theme.namedScheme;
        if (named && named[key] !== undefined)
            return named[key];
        if (R.Theme.matchWallpaper && R.Scheme.roles && R.Scheme.roles[key] !== undefined)
            return R.Scheme.roles[key];
        if (R.Theme[key] !== undefined)
            return R.Theme[key];
        if (aliases[key] !== undefined)
            return role(aliases[key], fallback);
        return fallback;
    }

    function getLuminance(c: color): real {
        if (c.r == 0 && c.g == 0 && c.b == 0)
            return 0;
        return Math.sqrt(0.299 * (c.r ** 2) + 0.587 * (c.g ** 2) + 0.114 * (c.b ** 2));
    }

    function alterColour(c: color, a: real, layer: int): color {
        const luminance = getLuminance(c);

        const offset = (!light || layer == 1 ? 1 : -layer / 2) * (light ? 0.2 : 0.3) * (1 - transparency.base) * (1 + wallLuminance * (light ? (layer == 1 ? 3 : 1) : 2.5));
        const scale = (luminance + offset) / luminance;
        const r = Math.max(0, Math.min(1, c.r * scale));
        const g = Math.max(0, Math.min(1, c.g * scale));
        const b = Math.max(0, Math.min(1, c.b * scale));

        return Qt.rgba(r, g, b, a);
    }

    function layer(c: color, layer: var): color {
        if (!transparency.enabled)
            return c;

        return layer === 0 ? Qt.alpha(c, transparency.base) : alterColour(c, transparency.layers, layer ?? 1);
    }

    function on(c: color): color {
        if (c.hslLightness < 0.5)
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.9, 1);
        return Qt.hsla(c.hslHue, c.hslSaturation, 0.1, 1);
    }

    component Transparency: QtObject {
        readonly property bool enabled: Tokens.transparency.enabled
        readonly property real base: Math.max(0, Math.min(1, Tokens.transparency.base - (root.light ? 0.1 : 0)))
        readonly property real layers: Math.max(0, Math.min(1, Tokens.transparency.layers))
    }

    component M3TPalette: QtObject {
        readonly property color m3primary_paletteKeyColor: root.layer(root.palette.m3primary_paletteKeyColor)
        readonly property color m3secondary_paletteKeyColor: root.layer(root.palette.m3secondary_paletteKeyColor)
        readonly property color m3tertiary_paletteKeyColor: root.layer(root.palette.m3tertiary_paletteKeyColor)
        readonly property color m3neutral_paletteKeyColor: root.layer(root.palette.m3neutral_paletteKeyColor)
        readonly property color m3neutral_variant_paletteKeyColor: root.layer(root.palette.m3neutral_variant_paletteKeyColor)
        readonly property color m3background: root.layer(root.palette.m3background, 0)
        readonly property color m3onBackground: root.layer(root.palette.m3onBackground)
        readonly property color m3surface: root.layer(root.palette.m3surface, 0)
        readonly property color m3surfaceDim: root.layer(root.palette.m3surfaceDim, 0)
        readonly property color m3surfaceBright: root.layer(root.palette.m3surfaceBright, 0)
        readonly property color m3surfaceContainerLowest: root.layer(root.palette.m3surfaceContainerLowest)
        readonly property color m3surfaceContainerLow: root.layer(root.palette.m3surfaceContainerLow)
        readonly property color m3surfaceContainer: root.layer(root.palette.m3surfaceContainer)
        readonly property color m3surfaceContainerHigh: root.layer(root.palette.m3surfaceContainerHigh)
        readonly property color m3surfaceContainerHighest: root.layer(root.palette.m3surfaceContainerHighest)
        readonly property color m3onSurface: root.layer(root.palette.m3onSurface)
        readonly property color m3surfaceVariant: root.layer(root.palette.m3surfaceVariant, 0)
        readonly property color m3onSurfaceVariant: root.layer(root.palette.m3onSurfaceVariant)
        readonly property color m3inverseSurface: root.layer(root.palette.m3inverseSurface, 0)
        readonly property color m3inverseOnSurface: root.layer(root.palette.m3inverseOnSurface)
        readonly property color m3outline: root.layer(root.palette.m3outline)
        readonly property color m3outlineVariant: root.layer(root.palette.m3outlineVariant)
        readonly property color m3shadow: root.layer(root.palette.m3shadow)
        readonly property color m3scrim: root.layer(root.palette.m3scrim)
        readonly property color m3surfaceTint: root.layer(root.palette.m3surfaceTint)
        readonly property color m3primary: root.layer(root.palette.m3primary)
        readonly property color m3onPrimary: root.layer(root.palette.m3onPrimary)
        readonly property color m3primaryContainer: root.layer(root.palette.m3primaryContainer)
        readonly property color m3onPrimaryContainer: root.layer(root.palette.m3onPrimaryContainer)
        readonly property color m3inversePrimary: root.layer(root.palette.m3inversePrimary)
        readonly property color m3secondary: root.layer(root.palette.m3secondary)
        readonly property color m3onSecondary: root.layer(root.palette.m3onSecondary)
        readonly property color m3secondaryContainer: root.layer(root.palette.m3secondaryContainer)
        readonly property color m3onSecondaryContainer: root.layer(root.palette.m3onSecondaryContainer)
        readonly property color m3tertiary: root.layer(root.palette.m3tertiary)
        readonly property color m3onTertiary: root.layer(root.palette.m3onTertiary)
        readonly property color m3tertiaryContainer: root.layer(root.palette.m3tertiaryContainer)
        readonly property color m3onTertiaryContainer: root.layer(root.palette.m3onTertiaryContainer)
        readonly property color m3error: root.layer(root.palette.m3error)
        readonly property color m3onError: root.layer(root.palette.m3onError)
        readonly property color m3errorContainer: root.layer(root.palette.m3errorContainer)
        readonly property color m3onErrorContainer: root.layer(root.palette.m3onErrorContainer)
        readonly property color m3success: root.layer(root.palette.m3success)
        readonly property color m3onSuccess: root.layer(root.palette.m3onSuccess)
        readonly property color m3successContainer: root.layer(root.palette.m3successContainer)
        readonly property color m3onSuccessContainer: root.layer(root.palette.m3onSuccessContainer)
        readonly property color m3primaryFixed: root.layer(root.palette.m3primaryFixed)
        readonly property color m3primaryFixedDim: root.layer(root.palette.m3primaryFixedDim)
        readonly property color m3onPrimaryFixed: root.layer(root.palette.m3onPrimaryFixed)
        readonly property color m3onPrimaryFixedVariant: root.layer(root.palette.m3onPrimaryFixedVariant)
        readonly property color m3secondaryFixed: root.layer(root.palette.m3secondaryFixed)
        readonly property color m3secondaryFixedDim: root.layer(root.palette.m3secondaryFixedDim)
        readonly property color m3onSecondaryFixed: root.layer(root.palette.m3onSecondaryFixed)
        readonly property color m3onSecondaryFixedVariant: root.layer(root.palette.m3onSecondaryFixedVariant)
        readonly property color m3tertiaryFixed: root.layer(root.palette.m3tertiaryFixed)
        readonly property color m3tertiaryFixedDim: root.layer(root.palette.m3tertiaryFixedDim)
        readonly property color m3onTertiaryFixed: root.layer(root.palette.m3onTertiaryFixed)
        readonly property color m3onTertiaryFixedVariant: root.layer(root.palette.m3onTertiaryFixedVariant)
    }

    component M3Palette: QtObject {
        readonly property color m3primary_paletteKeyColor: root.role("primaryPaletteKeyColor", "#a8627b")
        readonly property color m3secondary_paletteKeyColor: root.role("secondaryPaletteKeyColor", "#8e6f78")
        readonly property color m3tertiary_paletteKeyColor: root.role("tertiaryPaletteKeyColor", "#986e4c")
        readonly property color m3neutral_paletteKeyColor: root.role("neutralPaletteKeyColor", "#807477")
        readonly property color m3neutral_variant_paletteKeyColor: root.role("neutral_variantPaletteKeyColor", "#837377")
        readonly property color m3background: root.role("background", "#191114")
        readonly property color m3onBackground: root.role("onBackground", "#efdfe2")
        readonly property color m3surface: root.role("surface", "#191114")
        readonly property color m3surfaceDim: root.role("surfaceDim", "#191114")
        readonly property color m3surfaceBright: root.role("surfaceBright", "#403739")
        readonly property color m3surfaceContainerLowest: root.role("surfaceContainerLowest", "#130c0e")
        readonly property color m3surfaceContainerLow: root.role("surfaceContainerLow", "#22191c")
        readonly property color m3surfaceContainer: root.role("surfaceContainer", "#261d20")
        readonly property color m3surfaceContainerHigh: root.role("surfaceContainerHigh", "#31282a")
        readonly property color m3surfaceContainerHighest: root.role("surfaceContainerHighest", "#3c3235")
        readonly property color m3onSurface: root.role("onSurface", "#efdfe2")
        readonly property color m3surfaceVariant: root.role("surfaceVariant", "#514347")
        readonly property color m3onSurfaceVariant: root.role("onSurfaceVariant", "#d5c2c6")
        readonly property color m3inverseSurface: root.role("inverseSurface", "#efdfe2")
        readonly property color m3inverseOnSurface: root.role("inverseOnSurface", "#372e30")
        readonly property color m3outline: root.role("outline", "#9e8c91")
        readonly property color m3outlineVariant: root.role("outlineVariant", "#514347")
        readonly property color m3shadow: root.role("shadow", "#000000")
        readonly property color m3scrim: root.role("scrim", "#000000")
        readonly property color m3surfaceTint: root.role("surfaceTint", "#ffb0ca")
        readonly property color m3primary: root.role("primary", "#ffb0ca")
        readonly property color m3onPrimary: root.role("onPrimary", "#541d34")
        readonly property color m3primaryContainer: root.role("primaryContainer", "#6f334a")
        readonly property color m3onPrimaryContainer: root.role("onPrimaryContainer", "#ffd9e3")
        readonly property color m3inversePrimary: root.role("inversePrimary", "#8b4a62")
        readonly property color m3secondary: root.role("secondary", "#e2bdc7")
        readonly property color m3onSecondary: root.role("onSecondary", "#422932")
        readonly property color m3secondaryContainer: root.role("secondaryContainer", "#5a3f48")
        readonly property color m3onSecondaryContainer: root.role("onSecondaryContainer", "#ffd9e3")
        readonly property color m3tertiary: root.role("tertiary", "#f0bc95")
        readonly property color m3onTertiary: root.role("onTertiary", "#48290c")
        readonly property color m3tertiaryContainer: root.role("tertiaryContainer", "#b58763")
        readonly property color m3onTertiaryContainer: root.role("onTertiaryContainer", "#000000")
        readonly property color m3error: root.role("error", "#ffb4ab")
        readonly property color m3onError: root.role("onError", "#690005")
        readonly property color m3errorContainer: root.role("errorContainer", "#93000a")
        readonly property color m3onErrorContainer: root.role("onErrorContainer", "#ffdad6")
        readonly property color m3success: root.role("success", "#B5CCBA")
        readonly property color m3onSuccess: root.role("onSuccess", "#213528")
        readonly property color m3successContainer: root.role("successContainer", "#374B3E")
        readonly property color m3onSuccessContainer: root.role("onSuccessContainer", "#D1E9D6")
        readonly property color m3primaryFixed: root.role("primaryFixed", "#ffd9e3")
        readonly property color m3primaryFixedDim: root.role("primaryFixedDim", "#ffb0ca")
        readonly property color m3onPrimaryFixed: root.role("onPrimaryFixed", "#39071f")
        readonly property color m3onPrimaryFixedVariant: root.role("onPrimaryFixedVariant", "#6f334a")
        readonly property color m3secondaryFixed: root.role("secondaryFixed", "#ffd9e3")
        readonly property color m3secondaryFixedDim: root.role("secondaryFixedDim", "#e2bdc7")
        readonly property color m3onSecondaryFixed: root.role("onSecondaryFixed", "#2b151d")
        readonly property color m3onSecondaryFixedVariant: root.role("onSecondaryFixedVariant", "#5a3f48")
        readonly property color m3tertiaryFixed: root.role("tertiaryFixed", "#ffdcc3")
        readonly property color m3tertiaryFixedDim: root.role("tertiaryFixedDim", "#f0bc95")
        readonly property color m3onTertiaryFixed: root.role("onTertiaryFixed", "#2f1500")
        readonly property color m3onTertiaryFixedVariant: root.role("onTertiaryFixedVariant", "#623f21")
    }
}
