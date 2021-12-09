local lsp = require("vim.lsp")
local util = require("trouble.util")

---@class Lsp
local M = {}

---@param options TroubleOptions
---@return Item[]
function M.diagnostics(_win, buf, cb, options)
  local buffer_diags = {}
  if options.mode == "lsp_workspace_diagnostics" then
    buf = nil
    buffer_diags = vim.lsp.diagnostic.get_all()
  else
    buffer_diags = vim.diagnostic.get(buf)
    vim.tbl_map(
      function (item)
        item.range = {
          ["end"] = {
            character = item.end_col,
            line = item.end_lnum
          },
          ["start"] = {
            character = item.col,
            line = item.lnum
          }
        }
        return item
      end,
      buffer_diags
    )
    buffer_diags = { [buf] = buffer_diags }
  end

  local items = util.locations_to_items(buffer_diags, 1)
  cb(items)
end

local function lsp_buf_request(buf, method, params, handler)
  lsp.buf_request(buf, method, params, function(err, m, result)
    handler(err, method == m and result or m)
  end)
end

---@return Item[]
function M.references(win, buf, cb, _options)
  local method = "textDocument/references"
  local params = util.make_position_params(win, buf)
  params.context = { includeDeclaration = true }
  lsp_buf_request(buf, method, params, function(err, result)
    if err then
      util.error("an error happened getting references: " .. err.message)
      return cb({})
    end
    if result == nil or #result == 0 then
      return cb({})
    end
    local ret = util.locations_to_items({ result }, 0)
    cb(ret)
  end)
end

---@return Item[]
function M.implementations(win, buf, cb, _options)
  local method = "textDocument/implementation"
  local params = util.make_position_params(win, buf)
  params.context = { includeDeclaration = true }
  lsp_buf_request(buf, method, params, function(err, result)
    if err then
      util.error("an error happened getting implementation: " .. err.message)
      return cb({})
    end
    if result == nil or #result == 0 then
      return cb({})
    end
    local ret = util.locations_to_items({ result }, 0)
    cb(ret)
  end)
end

---@return Item[]
function M.definitions(win, buf, cb, _options)
  local method = "textDocument/definition"
  local params = util.make_position_params(win, buf)
  params.context = { includeDeclaration = true }
  lsp_buf_request(buf, method, params, function(err, result)
    if err then
      util.error("an error happened getting definitions: " .. err.message)
      return cb({})
    end
    if result == nil or #result == 0 then
      return cb({})
    end
    for _, value in ipairs(result) do
      value.uri = value.targetUri or value.uri
      value.range = value.targetSelectionRange or value.range
    end
    local ret = util.locations_to_items({ result }, 0)
    cb(ret)
  end)
end

---@return Item[]
function M.type_definitions(win, buf, cb, _options)
  local method = "textDocument/typeDefinition"
  local params = util.make_position_params(win, buf)
  lsp_buf_request(buf, method, params, function(err, result)
    if err then
      util.error("an error happened getting type definitions: " .. err.message)
      return cb({})
    end
    if result == nil or #result == 0 then
      return cb({})
    end
    for _, value in ipairs(result) do
      value.uri = value.targetUri or value.uri
      value.range = value.targetSelectionRange or value.range
    end
    local ret = util.locations_to_items({ result }, 0)
    cb(ret)
  end)
end

function M.get_signs()
  local signs = {}
  for _, v in pairs(util.severity) do
    if v ~= "Other" then
      -- pcall to catch entirely unbound or cleared out sign hl group
      local status, sign = pcall(function()
        return vim.trim(vim.fn.sign_getdefined(util.get_severity_label(v, "Sign"))[1].text)
      end)
      if not status then
        sign = v:sub(1, 1)
      end
      signs[string.lower(v)] = sign
    end
  end
  return signs
end

return M
