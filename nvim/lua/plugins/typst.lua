return {
    'chomosuke/typst-preview.nvim',
    config = function()
        require("typst-preview").setup({
            dependencies_bin = {
                ['tinymist'] = 'tinymist', -- use mason's version
                ['websocat'] = nil
            },
        })
    end,
}

