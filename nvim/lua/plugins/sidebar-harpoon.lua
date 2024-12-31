return {
    -- dir = "~/Desktop/sidebar-harpoon",
    -- name = "sidebar-harpoon",
    "IVSOP/sidebar-harpoon.nvim",
    dependencies = {
        "nvim-tree/nvim-tree.lua"
    },
    config = function()
        local sbh = require("sidebar-harpoon")

        sbh.create()

        vim.keymap.set("n", "<leader>e", function() sbh.toggle() end)
        vim.keymap.set("n", "<leader>t", function() sbh.focus_toggle() end)
    end
}

