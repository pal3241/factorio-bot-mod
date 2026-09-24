local V = require("bridge.validate")
local S = require("bridge.state")
local M = {}

local function text(value, field, maximum)
  if type(value) ~= "string" or #value < 1 or #value > maximum then
    V.fail("INVALID_ARGUMENT", field .. " must be a nonempty string of at most " .. maximum .. " bytes")
  end
  return value
end

function M.send(params)
  local message = text(params.message, "message", 512)
  local sender = params.sender == nil and "FactorioBot" or text(params.sender, "sender", 64)
  local rendered = {"", "[", sender, "] ", message}

  if params.force ~= nil then
    local force = game.forces[V.string(params.force, "force")]
    if not force then V.fail("NOT_FOUND", "force does not exist: " .. tostring(params.force)) end
    force.print(rendered)
  else
    game.print(rendered)
  end

  local result = {sender = sender, message = message, force = params.force}
  S.emit("chat.sent", result)
  return result
end

return M
