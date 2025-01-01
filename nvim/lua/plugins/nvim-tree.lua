return {
    "nvim-tree/nvim-tree.lua",
    -- version = "*",
    lazy = false,
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    config = function()
        require("nvim-tree").setup {
            view = {
                side = "right",
                -- centralize_selection = true,
            },
            filters = {
                dotfiles = true,
            },
            actions = {
                open_file = {
                    quit_on_open = false,  -- Close the tree when a file is opened
                }
            },
            renderer = {
                highlight_opened_files = "name",
            },
            update_focused_file = {
                enable = true,
            },

            vim.api.nvim_set_keymap("n", "<Leader>t", ":NvimTreeToggle<CR>", {noremap = true})
        }
    end,
}

