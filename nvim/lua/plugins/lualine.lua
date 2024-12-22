-- +-------------------------------------------------+
-- | A | B | C                             X | Y | Z |
-- +-------------------------------------------------+

-- TODO: reduce delay or switch out for another statusline

local diagnostics = {
    'diagnostics',
    -- ........ https://github.com/nvim-lualine/lualine.nvim?tab=readme-ov-file#diagnostics-component-options
}

local fileformat = {
    'fileformat',
    symbols = {
        unix = '', -- e712
        dos = '',  -- e70f
        mac = '',  -- e711
    }
}

local filename = {
    'filename',
    file_status = true,      -- Displays file status (readonly status, modified status)
    newfile_status = false,  -- Display new file status (new file means no write after created)
    path = 0,                -- 0: Just the filename
    -- 1: Relative path
    -- 2: Absolute path
    -- 3: Absolute path, with tilde as the home directory
    -- 4: Filename and parent dir, with tilde as the home directory

    shorting_target = 40,    -- Shortens path to leave 40 spaces in the window
    symbols = {
        modified = '•',      -- Text to show when the file is modified.
        readonly = '[R]',      -- Text to show when the file is non-modifiable or readonly.
        unnamed = '[No Name]', -- Text to show for unnamed buffers.
        newfile = '[New]',     -- Text to show for newly created file before first write
    }
}

local custom_lspstatus = {
    function()
        local buf_clients = vim.lsp.get_active_clients { bufnr = 0 }
        if #buf_clients == 0 then
            return "LSP Inactive"
        end

        local buf_client_names = {}
        local copilot_active = false

        -- add client
        for _, client in pairs(buf_clients) do
            if client.name ~= "null-ls" and client.name ~= "copilot" then
                if client.name == "GitHub Copilot" then
                    copilot_active = true
                else
                    table.insert(buf_client_names, client.name)
                end
            end
        end

        local unique_client_names = table.concat(buf_client_names, ", ")
        local language_servers = string.format("[%s]", unique_client_names)

        return language_servers
    end,
}

local lspstatus = {
    function()
        return require('lsp-progress').progress()
    end

    -- -- listen lsp-progress event and refresh lualine
    -- vim.api.nvim_create_augroup("lualine_augroup", { clear = true })
    -- vim.api.nvim_create_autocmd("User", {
    --     group = "lualine_augroup",
    --     pattern = "LspProgressStatusUpdated",
    --     callback = require("lualine").refresh,
    -- })
}

return {
    'nvim-lualine/lualine.nvim',
    dependencies = {
        -- 'nvim-tree/nvim-web-devicons',
        'linrongbin16/lsp-progress.nvim'
    },
    -- lazy = false,
    event = { "VimEnter" },

    config = function()
        require('lualine').setup {
            options = {
                icons_enabled = true,
                theme = 'auto',
                component_separators = { left = '', right = ''},
                section_separators = { left = '', right = ''},
                disabled_filetypes = {
                    statusline = {},
                    winbar = {},
                },
                ignore_focus = {},
                always_divide_middle = true,
                always_show_tabline = true,
                globalstatus = false,
                refresh = {
                    statusline = 100,
                    tabline = 100,
                    winbar = 100,
                }
            },
            sections = {
                lualine_a = {'mode'},
                lualine_b = {'branch', 'diff', diagnostics},
                lualine_c = {},
                lualine_x = {lspstatus},
                lualine_y = {filename, fileformat},
                lualine_z = {'location'}
            },
            inactive_sections = {
                lualine_a = {},
                lualine_b = {},
                lualine_c = {'filename'},
                lualine_x = {'location'},
                lualine_y = {},
                lualine_z = {}
            },
            tabline = {},
            winbar = {},
            inactive_winbar = {},
            extensions = {}
        }
    end
}

