---@generic T
---@param list T[]
---@return T[]
local function deduplicate(list)
  local set = {}
  local ret = {}
  for _, elem in ipairs(list) do
    if set[elem] == nil then
      set[elem] = true
      table.insert(ret, elem)
    end
  end
  return ret
end

---@class ddc_source_lsp_config
---@field override_capabilities boolean Defalut: true
---@field respect_trigger boolean Defalut: true
local default_config = {
  override_capabilities = true,
  respect_trigger = true,
}

local M = {}

---@param opt ddc_source_lsp_config
function M.setup(opt)
  vim.validate({
    opt = { opt, "t", true },
  })
  opt = vim.tbl_extend("force", {}, default_config, opt or {}) --[[@as ddc_source_lsp_config]]

  if opt.override_capabilities then
    local ok1, lspconfig = pcall(require, "lspconfig")
    if not ok1 then
      vim.notify("nvim-lspconfig is not loaded")
    end

    lspconfig.util.on_setup = lspconfig.util.add_hook_before(
      lspconfig.util.on_setup,
      function(config)
        local ok2, ddc_nvim_lsp = pcall(require, "ddc_source_lsp")
        if not ok2 then
          vim.notify("ddc-source-lsp is not loaded")
        end
        local capabilities = ddc_nvim_lsp.make_client_capabilities()
        config.capabilities = capabilities
      end
    )
  end

  if opt.respect_trigger then
    vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
      group = vim.api.nvim_create_augroup("setup-triggerCharacters", {}),
      callback = function()
        ---@type string[]
        local chars = {}
        -- Support release version
        local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
        for _, client in ipairs(get_clients({ bufnr = 0 })) do
          local provider = client.server_capabilities.completionProvider
          if provider and provider.triggerCharacters then
            chars = vim.list_extend(chars, provider.triggerCharacters)
          end
        end
        chars = deduplicate(chars)
        for i = #chars, 1, -1 do
          if chars[i]:find("^%s$") then
            table.remove(chars, i)
          end
        end
        table.insert(chars, 1, "[a-zA-Z]")
        local regex = "(?:" .. table.concat(chars, "|\\") .. ")"
        vim.fn["ddc#custom#patch_buffer"]("sourceOptions", {
          ["lsp"] = {
            forceCompletionPattern = regex,
          },
        })
      end,
    })
  end
end

return M
