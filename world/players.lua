local V = require("bridge.validate")
local E = require("world.entities")
local M = {}

local function view(player)
  local surface = player.physical_surface or player.surface
  local position = player.physical_position or player.position
  return {
    index = player.index,
    name = player.name,
    connected = player.connected,
    force = player.force.name,
    surface = surface.name,
    position = {x = position.x, y = position.y},
    controller_type = player.controller_type,
    character = player.character and player.character.valid and E.summary(player.character) or nil
  }
end

local function resolve(params)
  if type(params.player_index) == "number" then
    local index = V.integer(params.player_index, "player_index", 1, 4294967295)
    local player = game.get_player(index)
    if not player then V.fail("NOT_FOUND", "player index does not exist: " .. index) end
    return player
  end

  if type(params.name) == "string" then
    local name = V.string(params.name, "name")
    local player = game.get_player(name)
    if not player then V.fail("NOT_FOUND", "player does not exist: " .. name) end
    return player
  end

  V.fail("INVALID_ARGUMENT", "provide either player_index or name")
end

function M.list(params)
  local rows = {}
  for _, player in pairs(game.players) do rows[#rows + 1] = view(player) end
  table.sort(rows, function(a, b) return a.index < b.index end)
  return V.page(rows, params)
end

function M.get(params)
  return view(resolve(params))
end

function M.location(params)
  local player = resolve(params)
  local surface = player.physical_surface or player.surface
  local position = player.physical_position or player.position
  return {
    player_index = player.index,
    name = player.name,
    connected = player.connected,
    force = player.force.name,
    surface = surface.name,
    position = {x = position.x, y = position.y}
  }
end

return M
