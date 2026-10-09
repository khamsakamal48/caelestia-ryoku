-- >>> caelestia-ryoku >>>
-- Caelestia bar style keybinds (added by caelestia-ryoku's install.sh).
-- Ryoku's own launcher moved to SUPER + SHIFT + Space (Ryoku Hub > Keybinds).
-- Delete this block to undo; the shortcuts are Caelestia's global names.
hl.bind("SUPER + Space", hl.dsp.global("caelestia:launcher"))   -- Caelestia launcher
hl.bind("SUPER + G", hl.dsp.global("caelestia:sidebar"))        -- notification sidebar
hl.bind("SUPER + I", hl.dsp.global("caelestia:nexus"))          -- Nexus settings
hl.unbind("SUPER + Escape")                                      -- drop Ryoku's frame-menu quick settings
hl.bind("SUPER + Escape", hl.dsp.global("caelestia:quicksettings")) -- quick settings as a Caelestia drawer
hl.window_rule({
    name   = "caelestia-nexus-float",
    match  = { class = "org\\.quickshell", title = "Nexus.*" },
    float  = true,
    center = true,
})
-- <<< caelestia-ryoku <<<
