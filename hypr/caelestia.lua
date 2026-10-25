-- >>> caelestia-ryoku >>>
-- Caelestia bar style keybinds (added by caelestia-ryoku's install.sh).
-- Delete this block to undo; the shortcuts are Caelestia's global names.
hl.bind("SUPER + G", hl.dsp.global("caelestia:sidebar"))        -- notification sidebar
hl.bind("SUPER + I", hl.dsp.global("caelestia:nexus"))          -- Nexus settings
hl.window_rule({
    name   = "caelestia-nexus-float",
    match  = { class = "org\\.quickshell", title = "Nexus.*" },
    float  = true,
    center = true,
})
-- <<< caelestia-ryoku <<<
