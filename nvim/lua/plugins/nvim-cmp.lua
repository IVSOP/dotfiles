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

return {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
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
                completeopt = "menu,menuone,preview,noselect"
            },
            snippet = {
                expand = function(args)
                    vim.snippet.expand(args.body)
                end
            },
            mapping = {
                ["<Down>"] = cmp.mapping.select_next_item(),
                ["<Up>"] = cmp.mapping.select_prev_item(),
                ['<C-Space>'] = cmp.mapping.confirm {
                    behavior = cmp.ConfirmBehavior.Insert,
                    select = true,
                },
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
                -- ["<C-e>"] = cmp.mapping.abort(), -- .close(),
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

