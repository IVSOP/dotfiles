-- systemctl --user restart wireplumber
-- wpctl status
-- wpctl inspect <id>

-- WirePlumber script to configure microphone settings
local target_node_name = "alsa_input.usb-Razer_Inc._Razer_Seiren_V3_Mini-00.mono-fallback"

-- why is this so shit, should I set alsa bits to 24 as well????????? they are still at 16

rule = {
    matches = {
        {
            { "node.name", "equals", target_node_name },
        },
    },
    apply_properties = {
        ["audio.format"] = "S24_LE", -- 24-bit little-endian
        ["audio.rate"] = 48000,     -- 48 kHz
        ["audio.channels"] = 1,     -- Mono
    },
}

table.insert(alsa_monitor.rules,rule)

