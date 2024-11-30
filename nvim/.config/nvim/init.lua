--
-- Author: Ihor Kalnytskyi <ihor@kalnytskyi.com>
-- Source: https://git.io/JYNmy
--

--
-- // HELPERS //
--

-- These symbols essentially represent "single" border style. Once Telescope
-- supports built-in borders, we can probably replace them with just "single"
-- string.
local FLOAT_BORDER = { "┌", "─", "┐", "│", "┘", "─", "└", "│" }

-- LSP client capabilities to report to language server. Can be updated when
-- other plugins are used, hence is a global shared object.
local LSP_CLIENT_CAPABILITIES = vim.lsp.protocol.make_client_capabilities()

--
-- // OPTIONS //
--

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.showmode = false
vim.opt.scrolloff = 3
vim.opt.sidescrolloff = 3
vim.opt.shortmess:append("c")
vim.opt.title = true
vim.opt.completeopt = { "menu", "menuone", "noselect", "noinsert" }
vim.opt.updatetime = 300
vim.opt.colorcolumn = { 81, 101 }
vim.opt.cursorline = true
vim.opt.list = true
vim.opt.listchars = {
   tab      = "⇥-",
   lead     = "·",
   trail    = "·",
   nbsp     = "␣",
   extends  = "⟩",
   precedes = "⟨",
}
vim.opt.showbreak = "➥ "
vim.opt.foldenable = false
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.wrap = false
vim.opt.number = true
vim.opt.signcolumn = "yes"
vim.opt.expandtab = true
vim.opt.formatoptions:append("r")
vim.opt.formatoptions:append("n")
vim.opt.formatoptions:remove("t")
vim.opt.swapfile = false
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.spelllang = { "en", "uk" }
vim.opt.tabstop = 4
vim.opt.undofile = true
vim.opt.clipboard = "unnamedplus"
vim.opt.pumheight = 20
vim.opt.mousemodel = "extend"

vim.g.mapleader = " "

vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0

vim.g.netrw_keepdir = 0
vim.g.netrw_banner = 0
vim.g.netrw_winsize = 15


--
-- // CLIPBOARD //
--

-- When running NeoVim over SSH or in a Linux container, system clipboard
-- integration usually fails due to the lack of X11 or Wayland sockets. Using
-- OSC 52 escape codes can improve clipboard integration if supported by the
-- terminal emulator.
if os.getenv("SSH_TTY")                                -- ssh
    or vim.loop.fs_stat("/run/host/container-manager") -- systemd-nspawn
    or vim.loop.fs_stat("/.dockerenv")                 -- docker
then
   local osc52 = require("vim.ui.clipboard.osc52")
   vim.g.clipboard = {
      name = "OSC 52",
      copy = {
         ["+"] = osc52.copy("+"),
         ["*"] = osc52.copy("*"),
      },
      paste = {
         ["+"] = osc52.paste("+"),
         ["*"] = osc52.paste("*"),
      },
   }
end


--
-- // HOOKS //
--

vim.api.nvim_create_augroup("MyTextYank", {})
vim.api.nvim_create_autocmd("TextYankPost", {
   group = "MyTextYank",
   callback = function()
      require("vim.highlight").on_yank()
   end,
})


--
-- // LANGUAGES //
--

vim.filetype.add({
   extension = {
      ["rasi"] = "rasi",
   },
   pattern = {
      [".*/sway/config%.d/.*"] = "swayconfig",
      [".*/sway/config%..*"] = "swayconfig",
   },
})

vim.api.nvim_create_augroup("MyFiletypeOptions", {})
vim.api.nvim_create_autocmd("FileType", {
   group = "MyFiletypeOptions",
   pattern = "python",
   command = "setlocal comments+=b:#:", -- '#:' sphinx docstrings comments
})
vim.api.nvim_create_autocmd("FileType", {
   group = "MyFiletypeOptions",
   pattern = "dosini",
   command = "setlocal comments+=b:#", -- '#' common ini dialect
})


--
-- // LSP FRAMEWORK //
--

vim.api.nvim_create_augroup("MyLspAttach", { clear = true })
vim.api.nvim_create_autocmd("LspAttach", {
   group = "MyLspAttach",
   callback = function(ev)
      local lsp_client = vim.lsp.get_client_by_id(ev.data.client_id)
      local lsp_methods = vim.lsp.protocol.Methods
      local vim_lsp_buf_toggle_inlayhint = function()
         vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
      end

      for _, keymap in ipairs({
         { "n",          "gy",         vim.lsp.buf.type_definition,  "Goto type definition",            lsp_methods.textDocument_typeDefinition },
         { "n",          "gd",         vim.lsp.buf.definition,       "Goto definition",                 lsp_methods.textDocument_definition },
         { "n",          "gi",         vim.lsp.buf.implementation,   "Goto implementation",             lsp_methods.textDocument_implementation },
         { "n",          "gr",         vim.lsp.buf.references,       "Goto references",                 lsp_methods.textDocument_references },
         { "n",          "<Leader>r",  vim.lsp.buf.rename,           "Rename symbol",                   lsp_methods.textDocument_rename },
         { "n",          "<Leader>a",  vim.lsp.buf.code_action,      "Perform code action",             lsp_methods.textDocument_codeAction },
         { "i",          "<C-S>",      vim.lsp.buf.signature_help,   "Show signature",                  lsp_methods.textDocument_signatureHelp },
         { "n",          "<Leader>H",  vim_lsp_buf_toggle_inlayhint, "Toggle inlay hints",              lsp_methods.textDocument_inlayHint },
         { "n",          "<Leader>k",  vim.lsp.buf.hover,            "Show docs for item under cursor", lsp_methods.textDocument_hover },
         { "n",          "<Leader>s",  vim.lsp.buf.document_symbol,  "Open symbol picker",              lsp_methods.textDocument_documentSymbol },
         { "n",          "<Leader>S",  vim.lsp.buf.workspace_symbol, "Open workspace symbol picker",    lsp_methods.workspace_symbol },
         { { "n", "v" }, "<Leader>F",  vim.lsp.buf.format,           "Auto-format a buffer",            lsp_methods.textDocument_formatting },
      }) do
         if lsp_client.supports_method(keymap[5]) then
            vim.keymap.set(keymap[1], keymap[2], keymap[3], { buffer = ev.buf, desc = keymap[4] })
         end
      end

      if lsp_client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
         vim.api.nvim_create_augroup("MyLspHighlightReferences", {})
         vim.api.nvim_create_autocmd("CursorHold", {
            group = "MyLspHighlightReferences",
            callback = vim.lsp.buf.document_highlight,
            buffer = ev.buf,
         })
         vim.api.nvim_create_autocmd("CursorMoved", {
            group = "MyLspHighlightReferences",
            callback = vim.lsp.buf.clear_references,
            buffer = ev.buf,
         })
      end
   end,
})

vim.lsp.handlers[vim.lsp.protocol.Methods.textDocument_hover] = vim.lsp.with(
   vim.lsp.handlers.hover, {
      border = FLOAT_BORDER,
      focusable = false,
   }
)

vim.lsp.handlers[vim.lsp.protocol.Methods.textDocument_signatureHelp] = vim.lsp.with(
   vim.lsp.handlers.signature_help, {
      border = FLOAT_BORDER,
      focusable = false,
   }
)


--
-- // DIAGNOSTIC FRAMEWORK //
--

vim.diagnostic.config({
   virtual_text = false,
   severity_sort = true,
   float = {
      border = FLOAT_BORDER,
      focusable = false,
   },
   signs = {
      text = {
         [vim.diagnostic.severity.ERROR] = "",
         [vim.diagnostic.severity.WARN] = "",
         [vim.diagnostic.severity.INFO] = "",
         [vim.diagnostic.severity.HINT] = "",
      }
   }
})


--
-- // KEYBINDINGS //
--

vim.keymap.set("n", "<Leader>3", function() vim.wo.spell = not vim.wo.spell end, { desc = "Toggle spell checker" })
vim.keymap.set("n", "<Leader>d", vim.diagnostic.setloclist, { desc = "Open diagnostic picker" })


--
-- // PLUGINS //
--

-- Bootstrap the plugin manager, i.e. download the latest version from GitHub
-- if it's not yet downloaded.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
   vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "--single-branch",
      "https://github.com/folke/lazy.nvim.git",
      lazypath,
   })
end
vim.opt.runtimepath:prepend(lazypath)


require("lazy").setup({
   -- Fast asynchronous completion manager that works with omnicomplete, word
   -- completion and built-in LSP. The priority must be higher than of lspconfig
   -- plugin, because its config updates LSP client capabilities.
   {
      "hrsh7th/nvim-cmp",
      priority = 100,
      dependencies = {
         "dcampos/cmp-snippy",
         "hrsh7th/cmp-buffer",
         "hrsh7th/cmp-nvim-lsp",
         "hrsh7th/cmp-nvim-lsp-signature-help",
         "hrsh7th/cmp-nvim-lua",
         "hrsh7th/cmp-path",
      },
      config = function()
         local cmp = require("cmp")
         cmp.setup({
            completion = {
               completeopt = vim.o.completeopt,
            },
            window = {
               documentation = cmp.config.window.bordered({ border = FLOAT_BORDER }),
               completion = cmp.config.window.bordered({ border = FLOAT_BORDER }),
            },
            snippet = {
               expand = function(args)
                  vim.snippet.expand(args.body)
               end
            },
            preselect = cmp.PreselectMode.None,
            mapping = cmp.mapping.preset.insert(
               {
                  ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                  ["<C-f>"] = cmp.mapping.scroll_docs(4),
                  ["<C-Space>"] = cmp.mapping.complete(),
                  ["<Cr>"] = cmp.mapping.confirm(),
               }
            ),
            formatting = {
               format = function(_, vim_item)
                  vim_item.menu = vim_item.kind
                  vim_item.kind = MiniIcons.get("lsp", vim_item.kind)
                  return vim_item
               end
            },
            sources = cmp.config.sources({
               { name = "nvim_lsp" },
               { name = "nvim_lsp_signature_help" },
               { name = "nvim_lua" },
               { name = "buffer",                 keyword_length = 3 },
               { name = "snippy" },
               { name = "path" },
            }),
         })

         LSP_CLIENT_CAPABILITIES = vim.tbl_deep_extend(
            "force",
            LSP_CLIENT_CAPABILITIES,
            require("cmp_nvim_lsp").default_capabilities()
         )
      end,
   },

   -- The snippet engine of choice.
   {
      "dcampos/nvim-snippy",
      opts = {
         mappings = {
            is = {
               ["<Tab>"] = "expand_or_advance",
               ["<S-Tab>"] = "previous",
            },
         },
      },
   },

   -- Telescope is general fuzzy finder over lists that could be used to find
   -- files, grep projects, show LSP symbols, etc. One generic interface for
   -- lot of things.
   {
      "nvim-telescope/telescope.nvim",
      dependencies = {
         "nvim-lua/plenary.nvim",
         { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
         "nvim-telescope/telescope-file-browser.nvim",
         "nvim-telescope/telescope-ui-select.nvim",
      },
      config = function()
         local telescope = require("telescope")
         local telescope_actions = require("telescope.actions")
         local telescope_builtin = require("telescope.builtin")

         telescope.setup({
            defaults = {
               sorting_strategy = "ascending",
               layout_config = {
                  horizontal = {
                     height = 0.7,
                     prompt_position = "top",
                  },
               },
               -- Do not show prompt, selection, entry caret, keep UI simple.
               prompt_prefix = " ",
               selection_caret = " ",
               entry_prefix = " ",
               multi_icon = "",
               borderchars = {
                  -- Telescope doesn't support built-in borders yet :'(
                  FLOAT_BORDER[2],
                  FLOAT_BORDER[4],
                  FLOAT_BORDER[6],
                  FLOAT_BORDER[8],
                  FLOAT_BORDER[1],
                  FLOAT_BORDER[3],
                  FLOAT_BORDER[5],
                  FLOAT_BORDER[7],
               },
               results_title = false,
               prompt_title = false,
               mappings = {
                  i = {
                     -- I don't need Vim modes in Telescope, so any time Esc is
                     -- pressed I want to close Telescope instead of entering
                     -- Normal mode.
                     ["<Esc>"] = telescope_actions.close,
                     ["<C-Down>"] = telescope_actions.cycle_history_next,
                     ["<C-Up>"] = telescope_actions.cycle_history_prev,
                     ["<C-h>"] = "which_key",
                  },
               },
            },
            extensions = {
               aerial = {
                  show_nesting = {
                     ["_"] = true,
                  },
               },
               file_browser = {
                  git_status = false,
                  grouped = true,
                  hidden = true,
                  hijack_netrw = true,
                  mappings = {
                     i = {
                        -- Use the same shortcuts as telescope.nvim for
                        -- consistent experience.
                        ["<C-x>"] = telescope_actions.select_horizontal,
                        ["<C-v>"] = telescope_actions.select_vertical,
                        ["<C-t>"] = telescope_actions.select_tab,
                     },
                  },
               },
            },
         })
         telescope.load_extension("fzf")
         telescope.load_extension("projects")
         telescope.load_extension("file_browser")
         telescope.load_extension("ui-select")
         telescope.load_extension("aerial")

         vim.keymap.set("n", "<Leader>1", function()
            return telescope.extensions.file_browser.file_browser({ path = "%:p:h" })
         end, { desc = "Open file browser at current file directory" })
         vim.keymap.set("n", "<Leader>f", telescope_builtin.git_files, { desc = "Open file picker" })
         vim.keymap.set("n", "<Leader>/", telescope_builtin.live_grep, { desc = "Open search in workspace directory" })
         vim.keymap.set("n", "<Leader>.", telescope_builtin.grep_string, { desc = "Search for a string under cursor" })
         vim.keymap.set("n", "<Leader>'", telescope_builtin.resume, { desc = "Open last picker" })
         vim.keymap.set("n", "<Leader>?", telescope_builtin.commands, { desc = "Open command palette" })
         vim.keymap.set("n", "<Leader>d", function()
            telescope_builtin.diagnostics({ bufnr = 0, no_sign = true })
         end, { desc = "Open diagnostic picker" })
         vim.keymap.set("n", "<Leader>g", function ()
            return telescope_builtin.git_status({ expand_dir = false })
         end, { desc = "Open changed file picker" })

         vim.api.nvim_create_autocmd("LspAttach", {
            group = "MyLspAttach",
            callback = function(ev)
               local lsp_client = vim.lsp.get_client_by_id(ev.data.client_id)
               local lsp_methods = vim.lsp.protocol.Methods

               -- These are Telescope keymap overwrites to provide a better UI
               -- than standard NeoVim does.
               for _, keymap in ipairs({
                  { "n", "gy",        telescope_builtin.lsp_type_definitions,          "Goto type definition",         lsp_methods.textDocument_typeDefinition },
                  { "n", "gd",        telescope_builtin.lsp_definitions,               "Goto definition",              lsp_methods.textDocument_definition },
                  { "n", "gi",        telescope_builtin.lsp_implementations,           "Goto implementation",          lsp_methods.textDocument_implementation },
                  { "n", "gr",        telescope_builtin.lsp_references,                "Goto references",              lsp_methods.textDocument_references },
                  { "n", "<Leader>s", telescope.extensions.aerial.aerial,              "Open symbol picker",           lsp_methods.textDocument_documentSymbol },
                  { "n", "<Leader>S", telescope_builtin.lsp_dynamic_workspace_symbols, "Open workspace symbol picker", lsp_methods.workspace_symbol },
               }) do
                  if lsp_client.supports_method(keymap[5]) then
                     vim.keymap.set(keymap[1], keymap[2], keymap[3], { buffer = ev.buf, desc = keymap[4] })
                  end
               end
            end
         })
      end,
   },

   -- LSP and its goodies.
   {
      "neovim/nvim-lspconfig",
      dependencies = { "b0o/SchemaStore.nvim" },
      config = function()
         local lspconfig = require("lspconfig")
         local server_settings = {
            pyright = {
               pyright = {
                  disableOrganizeImports = true,
               },
               python = {
                  analysis = {
                     autoImportCompletions = false,
                     diagnosticSeverityOverrides = {
                        -- reportIncompatibleMethodOverride = false,
                     },
                  },
               },
            },
            ts_ls = {
               typescript = {
                  inlayHints = {
                     includeInlayParameterNameHints = "all",
                     includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                     includeInlayFunctionParameterTypeHints = true,
                     includeInlayVariableTypeHints = true,
                     includeInlayPropertyDeclarationTypeHints = true,
                     includeInlayFunctionLikeReturnTypeHints = true,
                     includeInlayEnumMemberValueHints = true,
                  },
               },
               javascript = {
                  inlayHints = {
                     includeInlayParameterNameHints = "all",
                     includeInlayParameterNameHintsWhenArgumentMatchesName = false,
                     includeInlayFunctionParameterTypeHints = true,
                     includeInlayVariableTypeHints = true,
                     includeInlayPropertyDeclarationTypeHints = true,
                     includeInlayFunctionLikeReturnTypeHints = true,
                     includeInlayEnumMemberValueHints = true,
                  },
               },
            },
            lua_ls = {
               Lua = {
                  hint = {
                     enable = true,
                  },
               },
            },
            jsonls = {
               json = {
                  schemas = require("schemastore").json.schemas(),
                  validate = { enable = true },
               },
            },
         }

         for _, server_name in ipairs({
            "bashls",
            "clangd",
            "cssls",
            "dotls",
            "gopls",
            "html",
            "jsonls",
            "lua_ls",
            "marksman",
            "pyright",
            "ruff",
            "rust_analyzer",
            "taplo",
            "ts_ls",
            "yamlls",
         }) do
            lspconfig[server_name].setup({
               capabilities = vim.deepcopy(LSP_CLIENT_CAPABILITIES),
               settings = server_settings[server_name] or vim.empty_dict(),
            })
         end
      end,
   },

   -- Tree-sitter is a parser generator tool and an incremental parsing
   -- library. NeoVim can leverage its functionality in various ways: semantic
   -- syntax highlighting, indentation, navigation, etc.
   {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      dependencies = { "apple/pkl-neovim" },
      config = function()
         require("nvim-treesitter.configs").setup({
            highlight = { enable = true },
            incremental_selection = {
               enable = true,
               keymaps = {
                  init_selection = "<C-Space>",
                  scope_incremental = "<C-Space>",
               },
            },
         })
      end,
   },

   -- Non default colorschemes and their configurations.
   {
      "gbprod/nord.nvim",
      priority = 200,
      config = function()
         require("nord").setup({
            diff = { mode = "fg" },
            styles = {
               comments = { italic = false },
            }
         })
         vim.cmd.colorscheme("nord")
      end,
   },
   {
      "folke/tokyonight.nvim",
      opts = {
         styles = {
            comments = { italic = false },
            keywords = { italic = false },
         },
         lualine_bold = true,
      },
   },

   {
      "nvim-lualine/lualine.nvim",
      config = function()
         local breadcrump_sep = " ⟩ "
         local format_hl = require("lualine.highlight").component_format_highlight

         require("lualine").setup({
            options = {
               globalstatus = true,
            },
            sections = {
               lualine_a = { "mode" },
               lualine_b = {
                  {
                     "filename",
                     path = 1,
                     separator = false,
                     fmt = function(str, ctx)
                        local path_separator = package.config:sub(1, 1)
                        local colorized_sep = ""
                            .. "%" .. format_hl({ name = "lualine_b_aerial_LLNonText" })
                            .. breadcrump_sep
                            .. "%" .. ctx.default_hl;
                        return str:gsub(path_separator, colorized_sep);
                     end
                  },
                  {
                     "aerial",
                     sep = breadcrump_sep,
                     sep_prefix = true,
                     padding = { left = 0, right = 1 },
                  },
               },
               lualine_c = {},
               lualine_x = {
                  { "vim.lsp.status():gsub('%%', '%%%%')", icon = "" },
               },
               lualine_y = {
                  "diagnostics",
                  {
                     "encoding",
                     cond = function()
                        -- UTF-8 is the de-facto standard encoding and is what
                        -- most users expect by default. There's no need to
                        -- show encoding unless it's something else.
                        local fenc = vim.opt.fenc:get()
                        return string.len(fenc) > 0 and string.lower(fenc) ~= "utf-8"
                     end,
                  },
                  "filetype",
                  "fileformat",
                  "progress",
               },
               lualine_z = { "location" },
            },
         })
      end,
   },
   {
      "stevearc/aerial.nvim",
      opts = {
         layout = {
            min_width = 40,
            max_width = 40,
         },
         highlight_on_jump = false,
         close_on_select = true,
         show_guides = true,
      },
      config = function(self, opts)
         require("aerial").setup(opts)
         vim.keymap.set("n", "<Leader>2", "<Cmd>AerialToggle!<Cr>", { desc = "Toggle code outline" })
      end,
   },
   {
      "ahmedkhalf/project.nvim",
      main = "project_nvim",
      config = true,
   },
   {
      "folke/which-key.nvim",
      opts = {
         preset = "modern",
         filter = function(mapping)
            -- Do not show key mappings w/o description, since it won't be
            -- useful anyway.
            return mapping.desc and mapping.desc ~= ""
         end,
      },
   },
   {
      "lewis6991/gitsigns.nvim",
      opts = {
         preview_config = {
            border = FLOAT_BORDER,
            focusable = false,
         },
         on_attach = function(buffer)
            local gitsigns = require("gitsigns")

            -- There's no need for next/prev hunk keymaps for diff buffers
            -- since they support them natively.
            if not vim.wo.diff then
               vim.keymap.set("n", "]c", gitsigns.next_hunk, { buffer = buffer, desc = "Goto next change" })
               vim.keymap.set("n", "[c", gitsigns.prev_hunk, { buffer = buffer, desc = "Goto previous change" })
            end

            vim.keymap.set({ "n", "v" }, "<Leader>hs", gitsigns.stage_hunk, { buffer = buffer, desc = "Stage current hunk"})
            vim.keymap.set({ "n", "v" }, "<Leader>hr", gitsigns.reset_hunk, { buffer = buffer, desc = "Revert current hunk" })
            vim.keymap.set("n", "<Leader>hu", gitsigns.undo_stage_hunk, { buffer = buffer, desc = "Unstage current hunk" })
            vim.keymap.set("n", "<Leader>hp", gitsigns.preview_hunk, { buffer = buffer, desc = "Show current hunk" })
            vim.keymap.set("n", "<Leader>hb", function() gitsigns.blame_line { full = true } end, { buffer = buffer, desc = "Blame current line" })
            vim.keymap.set("n", "<Leader>hd", function() gitsigns.diffthis("~") end, { buffer = buffer, desc = "Show current file diff" })
         end,
      }
   },
   {
      "norcalli/nvim-colorizer.lua",
      opts = {
         css = { css = true },
         stylus = { css = true },
      },
   },
   {
      "echasnovski/mini.icons",
      opts = {
         lsp = {
            ["function"] = { glyph = "󰊕" },
         },
      },
      config = function(self, opts)
         require("mini.icons").setup(opts)
         MiniIcons.mock_nvim_web_devicons()
      end,
   },
   { "tpope/vim-sleuth" },
   { "mg979/vim-visual-multi" },
   {
      "lukas-reineke/indent-blankline.nvim",
      main = "ibl",
      opts = {
         indent = { char = "│" },
         scope = { enabled = false },
      },
   },
   { "kylechui/nvim-surround", config = true },
   {
      "williamboman/mason.nvim",
      opts = {},
      cond = (vim.fn.hostname() == "jakku"),
   },
}, {
   lockfile = vim.fn.stdpath("data") .. "/lazy-lock.json",
   ui = { border = FLOAT_BORDER },
})


--
-- // SOURCE EXTRA CONFIGURATIONS //
--

for _, name in ipairs({ vim.fn.hostname(), "local" }) do
   local path = string.format("%s/init.%s.lua", vim.fn.stdpath("config"), name)

   if vim.fn.filereadable(path) == 1 then
      vim.cmd.source(path)
   end
end
