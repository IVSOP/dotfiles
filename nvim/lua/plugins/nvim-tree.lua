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
            vim.api.nvim_set_keymap("n", "<Leader>t", ":NvimTreeToggle<CR>", {noremap = true})
        }
    end,
}

