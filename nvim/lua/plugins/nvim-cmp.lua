-- https://github.com/hrsh7th/nvim-cmp/blob/main/doc/cmp.txt

local cmp_kinds = {
  Text = '  ',
  Method = '  ',
  Function = '  ',
  Constructor = '  ',
  Field = '  ',
  Variable = '  ',
  Class = '  ',
  Interface = '  ',
  Module = '  ',
  Property = '  ',
  Unit = '  ',
  Value = '  ',
  Enum = '  ',
  Keyword = '  ',
  Snippet = '  ',
  Color = '  ',
  File = '  ',
  Reference = '  ',
  Folder = '  ',
  EnumMember = '  ',
  Constant = '  ',
  Struct = '  ',
  Event = '  ',
  Operator = '  ',
  TypeParameter = '  ',
}

local has_words_before = function()
    unpack = unpack or table.unpack
    local line, col = unpack(vim.api.nvim_win_get_cursor(0))
    return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match('%s') == nil
end

return {
    "hrsh7th/nvim-cmp",
    -- event = "InsertEnter",
    dependencies = {
        "hrsh7th/cmp-buffer", -- buffer completion source for nvim-cmp
        "hrsh7th/cmp-path", -- path completion source for nvim-cmp
        "L3MON4D3/LuaSnip", -- snippet engine for nvim-cmp
        "saadparwaiz1/cmp_luasnip", -- LuaSnip completion source for nvim-cmp
        "rafamadriz/friendly-snippets", -- collection of common snippets for LuaSnip
    },
    config = function()
        local cmp = require("cmp")

        cmp.setup({
            completion = {
                completeopt = "menu,menuone,preview,noselect",
                autocomplete = false -- only show the menu when I ask for it
            },
            snippet = {
                expand = function(args)
                    vim.snippet.expand(args.body)
                end
            },
            mapping = {
                ["<Down>"] = cmp.mapping.select_next_item(),
                ["<Up>"] = cmp.mapping.select_prev_item(),
                -- ['<C-Space>'] = function () -- trigger menu open and close
                --     if cmp.visible() then -- close the menu if it is open
                --         cmp.close()
                --     else
                --         if has_words_before() then -- only show if there are words before
                --             -- repeated from what's below, only way for it to work for some reason
                --             cmp.complete({
                --                 config = {
                --                     sources = {
                --                         { name = "nvim_lsp" },
                --                         -- { name = "luasnip" },
                --                         { name = "buffer" },
                --                         { name = "path" },
                --                     }
                --                 }
                --             })
                --         end
                --     end
                -- end,

                -- if menu not shown and words before etc, then show it
                ['<Tab>'] = function(fallback)
                    if not cmp.select_next_item() then
                        if vim.bo.buftype ~= 'prompt' and has_words_before() then
                            cmp.complete()
                        else
                            fallback()
                        end
                    end
                end,

                ['<S-Tab>'] = function(fallback)
                    if not cmp.select_prev_item() then
                        if vim.bo.buftype ~= 'prompt' and has_words_before() then
                            cmp.complete()
                        else
                            fallback()
                        end
                    end
                end,
                -- ["<C-d>"] = cmp.mapping.scroll_docs(-4),
                -- ["<C-f>"] = cmp.mapping.scroll_docs(4),
                -- ["<C-Space>"] = cmp.mapping.complete(),
                ["<C-e>"] = cmp.mapping.close(), -- .close(),
                -- ["<CR>"] = cmp.mapping.confirm({
                --     behavior = cmp.ConfirmBehavior.Insert,
                --     select = true,
                -- }),
            },
            sources = {
                { name = "nvim_lsp" },
                -- { name = "luasnip" },
                { name = "buffer" },
                { name = "path" },
                -- https://github.com/hrsh7th/nvim-cmp/wiki/List-of-sources use git and rg??
            },
            window = {
                completion = cmp.config.window.bordered(),
                documentation = cmp.config.window.bordered(),
            },
            formatting = {
                fields = { "kind", "abbr", "menu" },
                expandable_indicator = true,
                format = function(_, vim_item)
                  vim_item.kind = cmp_kinds[vim_item.kind] or ""
                  return vim_item
                end,
            },
        })
    end,
}

