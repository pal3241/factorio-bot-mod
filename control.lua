local S = require("bridge.state")
local API = require("bridge.api")
local Actions = require("bot.actions")
local Events = require("bridge.events")

script.on_init(S.initialize)
script.on_configuration_changed(function()
  S.initialize()
  S.emit("world.invalidated", {reason = "configuration_changed"})
end)

remote.add_interface("factorio_bot_v1", {
  request_json = API.json
})

---@param command CustomCommandData
---@param execute fun(): string
local function admin_command(command, execute)
  if command.player_index then
    local player = game.get_player(command.player_index)
    if not player.admin then
      player.print(helpers.table_to_json({api_version = 1, ok = false,
        error = {code = "FORBIDDEN", message = "fbot requires administrator access"}}))
      return
    end
    player.print(execute())
  else
    rcon.print(execute())
  end
end

commands.add_command("fbot", "Versioned JSON world bridge; server console/RCON or admins only", function(command)
  admin_command(command, function() return API.json(command.parameter) end)
end)

commands.add_command("fbot-enable-actions", "Enable world bridge actions; administrator only", function(command)
  admin_command(command, function()
    settings.global["fbot-enable-actions"] = {value = true}
    return helpers.table_to_json({api_version = 1, ok = true, data = {actions_enabled = true}})
  end)
end)

commands.add_command("fbot-disable-actions", "Disable world bridge actions; administrator only", function(command)
  admin_command(command, function()
    settings.global["fbot-enable-actions"] = {value = false}
    return helpers.table_to_json({api_version = 1, ok = true, data = {actions_enabled = false}})
  end)
end)

Events.register()
script.on_event(defines.events.on_tick, Actions.tick)
script.on_nth_tick(60, API.sample)

local space_events = {}
for _, event_name in ipairs({"on_space_platform_built_entity", "on_space_platform_built_tile",
  "on_space_platform_mined_entity", "on_space_platform_mined_item", "on_space_platform_mined_tile",
  "on_space_platform_pre_mined", "on_space_platform_changed_state", "on_cargo_pod_delivered_cargo",
  "on_cargo_pod_finished_ascending", "on_cargo_pod_finished_descending", "on_cargo_pod_started_ascending",
  "on_rocket_launch_ordered", "on_rocket_launched"}) do
  local event_id = defines.events[event_name]
  if event_id then space_events[#space_events + 1] = event_id end
end
if #space_events > 0 then
  script.on_event(space_events, function(event)
    local entity = event.entity or event.platform or event.cargo_pod or event.rocket
    local unit_number, platform_index
    if entity and entity.valid then
      if entity.object_name == "LuaEntity" then unit_number = entity.unit_number end
      if entity.object_name == "LuaSpacePlatform" then platform_index = entity.index end
    end
    S.emit("space-age.invalidated", {event = event.name,
      surface = entity and entity.valid and entity.surface.name or nil,
      unit_number = unit_number, platform_index = platform_index})
  end)
end
