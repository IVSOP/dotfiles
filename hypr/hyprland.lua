------------------
---- MONITORS ----
------------------

hl.monitor({
    output    = "DP-1",
    mode      = "preferred",
    position  = "0x0",
    scale     = 1,
    transform = 1
})
hl.monitor({
    output    = "DP-3",
    mode      = "3840x2160@165",
    position  = "1440x506",
    scale     = 1.5,
})

---------------------
------- VARS --------
---------------------

-- Set programs that you use
local terminal    = "alacritty"
local fileManager = "nemo"
local menu        = 'rofi -modi "run#drun" -show drun -display-drun "Launch" -theme $HOME/.config/rofi/current-theme/dmenu-theme.rasi -font "cantarell regular 15" -show-icons -i'
local mainMod     = "SUPER"

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpm reload -n")
    hl.exec_cmd("~/.config/waybar/launch.sh")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("~/.config/dunst/get-theme.sh")
    hl.exec_cmd("~/.config/dunst/launch.sh")
    hl.exec_cmd("$HOME/Desktop/Rofi-Themer/Scripts/daemon.sh $HOME/Desktop/Rofi-Themer/data/")
    hl.exec_cmd("solaar --window hide")
    hl.exec_cmd("hyprsunset --temperature 5000")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("$HOME/.config/dunst/launch.sh")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.config({
    xwayland = {
        use_nearest_neighbor = false,
    },
})

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 2,
        gaps_out = 3,

        border_size = 3,

        col = {
            active_border   = "rgb(66CC66)",
            inactive_border = "rgb(0c0c0c)",
        },

        resize_on_border = false,
        allow_tearing = false,

        layout = "hy3",
    },

    decoration = {
        rounding       = 0,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled   = true,
            size      = 3,
            passes    = 1,
            vibrancy  = 0.1696,
        },
    },

    animations = {
        enabled = false,
    },
})

-- animations are actually disabled, but I kept these defaults
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Default springs
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

-- hy3 plugin config
hl.config({
    plugin = {
        hy3 = {
            node_collapse_policy = 2,
            group_inset = 0,
            tab_first_window = false,
            tabs = {
                height = 22,
                padding = 6,
                from_top = false,
                radius = 6,
                border_width = 2,
                render_text = true,
                text_center = true,
                text_font = "Sans",
                text_height = 8,
                text_padding = 3,
                blur = true,
                opacity = 1.0,
            },
            autotile = {
                enable = false,
            },

            indicator = {
                enable = true,
                color = 0xffe87272,
                width = 0
            }
        },
    },
})

--------------------------
---- WORKSPACE RULES ----
--------------------------

hl.workspace_rule({ workspace = "1", monitor = "DP-1" })
-- this way when I open steam it is always on DP-3
hl.workspace_rule({ workspace = "5", monitor = "DP-3" })

-----------------------
---- WINDOW RULES ----
-----------------------

hl.window_rule({ match = { class = "firefox" },  workspace = "1 silent" })
hl.window_rule({ match = { class = "discord" },  workspace = "1 silent" })
hl.window_rule({ match = { class = "steam" },    workspace = "5 silent" })

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
        vrr = 1,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "compose:ralt",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity   = -0.35, -- -1.0 - 1.0, 0 means no modification.
        accel_profile = "flat",

        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            disable_while_typing = false, -- Sway `dwt disabled`: touchpad stays active while typing
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

hl.device({
    name    = "logitech-pro-x",
    enabled = false,
})

hl.device({
    name          = "REPLACE-ME-touchpad-name",
    sensitivity   = 0.1,    -- Sway `pointer_accel 0.1`
    accel_profile = "flat", -- Sway `accel_profile "flat"`
})

---------------------
---- KEYBINDINGS ----
---------------------

-- Switching to the current workspace instead goes to the previous one (i3-like)
hl.config({
    binds = {
        workspace_back_and_forth = true,
    },
})

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))

-- hy3 layout controls (i3-style)
local hy3 = hl.plugin.hy3
hl.bind(mainMod .. " + W", hy3.make_group("tab"))
hl.bind(mainMod .. " + E", hy3.change_group("opposite"))
hl.bind(mainMod .. " + V", hy3.make_group("v"))
hl.bind(mainMod .. " + G", hy3.make_group("h"))
hl.bind(mainMod .. " + A", hy3.change_focus("raise"))   -- focus parent (select group)
hl.bind(mainMod .. " + SHIFT + A", hy3.change_focus("lower"))  -- focus child

-- App launchers
hl.bind(mainMod .. " + SHIFT + F1", hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + SHIFT + F2", hl.dsp.exec_cmd("discord --ozone-platform=wayland --enable-features=UseOzonePlatform"))
hl.bind(mainMod .. " + SHIFT + F3", hl.dsp.exec_cmd("steam"))

-- Toggle fullscreen
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

-- Screenshots
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("$HOME/.config/sway/scripts/screenshot-output.sh"))
hl.bind("Print", hl.dsp.exec_cmd("$HOME/.config/sway/scripts/screenshot.sh -m region"), { release = true })
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd("$HOME/.config/sway/scripts/screenshot.sh -m output"), { release = true })

-- Move focus with mainMod + arrow keys (hy3-aware)
hl.bind(mainMod .. " + left",  hy3.move_focus("l"))
hl.bind(mainMod .. " + right", hy3.move_focus("r"))
hl.bind(mainMod .. " + up",    hy3.move_focus("u"))
hl.bind(mainMod .. " + down",  hy3.move_focus("d"))

-- Move window with mainMod + SHIFT + arrow keys (hy3-aware)
hl.bind(mainMod .. " + SHIFT + left",  hy3.move_window("l"))
hl.bind(mainMod .. " + SHIFT + right", hy3.move_window("r"))
hl.bind(mainMod .. " + SHIFT + up",    hy3.move_window("u"))
hl.bind(mainMod .. " + SHIFT + down",  hy3.move_window("d"))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hy3.move_to_workspace(tostring(i), { follow = false }))
end

-- Go to / move window to the previous workspace
hl.bind(mainMod .. " + Tab",         hl.dsp.focus({ workspace = "previous" }))
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.window.move({ workspace = "previous", follow = false }))

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic", follow = false }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Resize helper: returns pixel amount as a % of the active monitor's dimension
local function resize_pct(axis, pct)
    local mon = hl.get_active_monitor()
    if axis == "x" then
        return math.floor(mon.width * pct / 100)
    else
        return math.floor(mon.height * pct / 100)
    end
end

-- Resize mode (5% steps)
hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    hl.bind("right", function() hl.dispatch(hl.dsp.window.resize({ x = resize_pct("x", 10), y = 0, relative = true })) end, { repeating = true })
    hl.bind("left",  function() hl.dispatch(hl.dsp.window.resize({ x = -resize_pct("x", 10), y = 0, relative = true })) end, { repeating = true })
    hl.bind("down",  function() hl.dispatch(hl.dsp.window.resize({ x = 0, y = resize_pct("y", 10), relative = true })) end, { repeating = true })
    hl.bind("up",    function() hl.dispatch(hl.dsp.window.resize({ x = 0, y = -resize_pct("y", 10), relative = true })) end, { repeating = true })
    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
end)

-- Small resize mode (2% steps)
hl.bind(mainMod .. " + CTRL + R", hl.dsp.submap("resize_small"))
hl.define_submap("resize_small", function()
    hl.bind("right", function() hl.dispatch(hl.dsp.window.resize({ x = resize_pct("x", 5), y = 0, relative = true })) end, { repeating = true })
    hl.bind("left",  function() hl.dispatch(hl.dsp.window.resize({ x = -resize_pct("x", 5), y = 0, relative = true })) end, { repeating = true })
    hl.bind("down",  function() hl.dispatch(hl.dsp.window.resize({ x = 0, y = resize_pct("y", 5), relative = true })) end, { repeating = true })
    hl.bind("up",    function() hl.dispatch(hl.dsp.window.resize({ x = 0, y = -resize_pct("y", 5), relative = true })) end, { repeating = true })
    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
end)

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("~/.config/hypr/scripts/sound.sh +5"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("~/.config/hypr/scripts/sound.sh -5"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("~/.config/hypr/scripts/sound.sh toggle-mute"),    { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})
