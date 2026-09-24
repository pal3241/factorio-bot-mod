local S = require("bridge.state")
local E = require("world.entities")
local M = {}

---@param event EventData
function M.entity(event)
  local entity = event.entity
  if entity and entity.valid then
    S.emit("entity.invalidated", {event = event.name, entity = E.summary(entity)})
  end
end

---@param event EventData
function M.chunk(event)
  S.emit("chunk.generated", {surface = event.surface.name, position = event.position, area = event.area})
end

---@param event EventData
function M.research(event)
  S.emit("research.changed", {event = event.name, force = event.research.force.name, technology = event.research.name})
end

---@param event EventData
function M.player(event)
  S.emit("player.changed", {event = event.name, player_index = event.player_index})
end

---@param event EventData.on_console_chat
function M.chat(event)
  local payload = {
    message = event.message,
    source = event.player_index and "player" or "server"
  }

  if event.player_index then
    local player = game.get_player(event.player_index)
    if player then
      local surface = player.physical_surface or player.surface
      local position = player.physical_position or player.position
      payload.player_index = player.index
      payload.player_name = player.name
      payload.connected = player.connected
      payload.force = player.force.name
      payload.surface = surface.name
      payload.position = {x = position.x, y = position.y}
    end
  end

  S.emit("chat.message", payload)
end

---@param event EventData
function M.tiles(event)
  S.emit("tiles.changed", {event = event.name, surface_index = event.surface_index})
end

---@param event EventData
function M.topology(event)
  S.emit("world.invalidated", {event = event.name})
end

function M.register()
  script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity,
    defines.events.script_raised_built, defines.events.script_raised_revive,
    defines.events.on_entity_died, defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity, defines.events.script_raised_destroy,
    defines.events.on_entity_spawned, defines.events.on_biter_base_built,
    defines.events.on_resource_depleted, defines.events.on_player_rotated_entity,
    defines.events.on_entity_damaged}, M.entity)
  script.on_event(defines.events.on_chunk_generated, M.chunk)
  script.on_event({defines.events.on_research_started, defines.events.on_research_finished,
    defines.events.on_research_reversed}, M.research)
  script.on_event(defines.events.on_console_chat, M.chat)
  script.on_event({defines.events.on_player_created, defines.events.on_player_joined_game,
    defines.events.on_player_left_game, defines.events.on_player_died, defines.events.on_player_respawned,
    defines.events.on_player_changed_surface, defines.events.on_player_main_inventory_changed}, M.player)
  script.on_event({defines.events.on_player_built_tile, defines.events.on_robot_built_tile,
    defines.events.on_player_mined_tile, defines.events.on_robot_mined_tile, defines.events.script_raised_set_tiles}, M.tiles)
  script.on_event({defines.events.on_surface_created, defines.events.on_surface_deleted,
    defines.events.on_surface_cleared, defines.events.on_forces_merged, defines.events.on_chunk_deleted,
    defines.events.on_research_cancelled, defines.events.on_train_created, defines.events.on_train_changed_state,
    defines.events.on_runtime_mod_setting_changed}, M.topology)
end

return M
