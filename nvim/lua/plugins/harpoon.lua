local function display(list)
    local sbh = require("sidebar-harpoon")
    -- sbh.display(list:display())
    sbh.display_and_select(list:display())
end

local function add()
    local harpoon = require("harpoon")
    local list = harpoon:list():add()
    display(list)
end

local function remove()
    local harpoon = require("harpoon")
    local list = harpoon:list():remove()
    display(list)
end

local function select(number)
    local harpoon = require("harpoon")
    local list = harpoon:list()
    list:select(number)
    -- local sbh = require("sidebar-harpoon")
    -- sbh.select(number)
    display(list)
end

return {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
        "IVSOP/sidebar-harpoon.nvim"
    },
    config = function()
        local harpoon = require("harpoon")

        -- REQUIRED
        harpoon:setup()
        -- REQUIRED

        vim.keymap.set("n", "<leader>a", add)
        -- vim.keymap.set("n", "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end) -- I use telescope, not this
        vim.keymap.set("n", "<leader>r", remove)
        vim.keymap.set("n", "<leader>x", function() harpoon:list():clear() end)

        vim.keymap.set("n", "<leader>1", function() select(1) end)
        vim.keymap.set("n", "<leader>2", function() select(2) end)
        vim.keymap.set("n", "<leader>3", function() select(3) end)
        vim.keymap.set("n", "<leader>4", function() select(4) end)

        -- Toggle previous & next buffers stored within Harpoon list
        vim.keymap.set("n", "<leader><Tab>", function() harpoon:list():next() end)
        vim.keymap.set("n", "<leader><S-Tab>", function() harpoon:list():prev() end)

        -- basic telescope configuration
        local conf = require("telescope.config").values
        local function toggle_telescope(harpoon_files)
            local file_paths = {}
            for _, item in ipairs(harpoon_files.items) do
                table.insert(file_paths, item.value)
            end

            require("telescope.pickers").new({}, {
                prompt_title = "Harpoon",
                finder = require("telescope.finders").new_table({
                    results = file_paths,
                }),
                previewer = conf.file_previewer({}),
                sorter = conf.generic_sorter({}),
            }):find()
        end

        vim.keymap.set("n", "<leader><S-e>", function() toggle_telescope(harpoon:list()) end,
            { desc = "Open harpoon window" })

        -- display at start
        display(harpoon:list())
    end
}

