return {
    'linrongbin16/lsp-progress.nvim',
    config = function()

        -- local api = require("lsp-progress.api")
        require('lsp-progress').setup({
            format = function(client_messages)
                -- icon: nf-fa-gear \uf013
                if #client_messages > 0 then
                    return table.concat(client_messages, " ")
                end
                local clients = vim.lsp.get_clients() -- api.lsp_clients()
                if #clients > 0 then
                    return clients[1].name
                end
                return ""
            end,
        })
    end
}

