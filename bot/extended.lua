local V = require("bridge.validate")
local S = require("bridge.state")
local R = require("bot.registry")
local E = require("world.entities")
local M = {}

local function set_action(bot, action)
  S.put("bots", bot.id, {
    id = bot.id,
    network = bot.network,
    entity = bot.entity,
    created_tick = bot.created_tick,
    action = action
  })
end

local function resolve_target(unit_number)
  local unit = V.integer(unit_number, "unit_number", 1, 4294967295)
  local target = game.get_entity_by_unit_number(unit)
  if not target or not target.valid then V.fail("NOT_FOUND", "entity unit_number does not exist: " .. unit) end
  return target
end

local function require_same_surface(character, target)
  if character.surface.index ~= target.surface.index then
    V.fail("UNREACHABLE_TARGET", "target is on another surface")
  end
end

local function require_reach(character, target)
  require_same_surface(character, target)
  if not character.can_reach_entity(target) then V.fail("UNREACHABLE_TARGET", "target is outside character reach") end
end

local function stack(params, count)
  local result = {
    name = V.string(params.name, "name"),
    count = count
  }
  if params.quality ~= nil then result.quality = V.string(params.quality, "quality") end
  return result
end

local function inventory_by_index(entity, index)
  if index == nil then
    local main = entity.get_main_inventory()
    if main then return main end
    for candidate = 1, entity.get_max_inventory_index() do
      local inventory = entity.get_inventory(candidate)
      if inventory then return inventory end
    end
    V.fail("NOT_FOUND", "entity has no inventory")
  end
  local checked = V.integer(index, "inventory_index", 1, 255)
  local inventory = entity.get_inventory(checked)
  if not inventory then V.fail("NOT_FOUND", "entity does not expose inventory index " .. checked) end
  return inventory
end

function M.inventory(params)
  local _, character = R.resolve(params)
  return {
    id = params.id,
    inventories = E.inventories(character),
    crafting_queue = character.crafting_queue or {},
    crafting_progress = character.crafting_queue_progress,
    selected_gun_index = character.selected_gun_index,
    vehicle_unit_number = character.vehicle and character.vehicle.unit_number or nil
  }
end

function M.transfer(params)
  local _, character = R.resolve(params)
  local target = resolve_target(params.unit_number)
  require_reach(character, target)

  local direction = V.string(params.direction, "direction")
  if direction ~= "to-entity" and direction ~= "from-entity" then
    V.fail("INVALID_ARGUMENT", "direction must be to-entity or from-entity")
  end

  local count = V.integer(params.count, "count", 1, 1000000)
  local character_inventory = inventory_by_index(character, params.bot_inventory_index)
  local target_inventory = inventory_by_index(target, params.target_inventory_index)
  local source = direction == "to-entity" and character_inventory or target_inventory
  local destination = direction == "to-entity" and target_inventory or character_inventory
  local requested = stack(params, count)

  local removed = source.remove(requested)
  if removed == 0 then V.fail("NOT_FOUND", "source inventory does not contain requested item") end

  local inserted = destination.insert(stack(params, removed))
  if inserted < removed then
    source.insert(stack(params, removed - inserted))
  end

  local result = {
    id = params.id,
    unit_number = target.unit_number,
    direction = direction,
    name = requested.name,
    quality = requested.quality,
    requested = count,
    moved = inserted
  }
  S.emit("bot.inventory_transferred", result)
  return result
end

function M.drop(params)
  local _, character = R.resolve(params)
  local count = V.integer(params.count, "count", 1, 1000000)
  local inventory = inventory_by_index(character, params.inventory_index)
  local requested = stack(params, count)
  local removed = inventory.remove(requested)
  if removed == 0 then V.fail("NOT_FOUND", "bot inventory does not contain requested item") end

  local entities = character.surface.spill_item_stack({
    position = character.position,
    stack = stack(params, removed),
    enable_looted = true,
    allow_belts = true,
    max_radius = 2
  })

  local result = {id = params.id, name = requested.name, quality = requested.quality, count = removed, spilled = #entities}
  S.emit("bot.item_dropped", result)
  return result
end

function M.pickup(params)
  local bot, character = R.resolve(params)
  local ticks = V.integer(params.ticks, "ticks", 1, 600)
  local action = {kind = "pickup", until_tick = game.tick + ticks}
  character.picking_state = true
  set_action(bot, action)
  S.emit("bot.action", {id = bot.id, action = action})
  return action
end

function M.attack(params)
  local bot, character = R.resolve(params)
  local target = resolve_target(params.unit_number)
  require_same_surface(character, target)
  local ticks = V.integer(params.ticks, "ticks", 1, 600)

  if not character.can_shoot(target, target.position) then
    V.fail("UNREACHABLE_TARGET", "bot cannot shoot target with current weapon/ammo")
  end

  local action = {kind = "attack", unit_number = target.unit_number, until_tick = game.tick + ticks}
  character.shooting_state = {state = defines.shooting.shooting_selected, position = target.position}
  set_action(bot, action)
  S.emit("bot.action", {id = bot.id, action = action})
  return action
end

function M.repair(params)
  local bot, character = R.resolve(params)
  local target = resolve_target(params.unit_number)
  require_reach(character, target)
  local ticks = V.integer(params.ticks, "ticks", 1, 600)
  local action = {kind = "repair", unit_number = target.unit_number, until_tick = game.tick + ticks}
  character.repair_state = {repairing = true, position = target.position}
  set_action(bot, action)
  S.emit("bot.action", {id = bot.id, action = action})
  return action
end

function M.place(params)
  local _, character = R.resolve(params)
  local name = V.string(params.name, "name")
  local position = V.position(params.position)
  local direction = V.integer(params.direction or 0, "direction", 0, 15)
  local prototype = prototypes.entity[name]
  if not prototype then V.fail("NOT_FOUND", "entity prototype does not exist: " .. name) end

  local dx, dy = position.x - character.position.x, position.y - character.position.y
  if dx * dx + dy * dy > character.build_distance * character.build_distance then
    V.fail("UNREACHABLE_TARGET", "placement is outside character build distance")
  end
  if not character.can_place_entity({name = name, position = position, direction = direction}) then
    V.fail("COLLISION", "character cannot place entity at requested position")
  end

  local place_items = prototype.items_to_place_this
  if not place_items or #place_items == 0 then
    V.fail("UNSUPPORTED_BUILDING", "entity has no item that can place it")
  end
  local item = place_items[1]
  local item_name = item.name
  local inventory = character.get_main_inventory()
  if not inventory then V.fail("NOT_FOUND", "character has no main inventory") end
  if inventory.remove({name = item_name, count = 1}) ~= 1 then
    V.fail("NOT_FOUND", "bot does not have required placement item: " .. item_name)
  end

  local entity = character.surface.create_entity({
    name = name,
    position = position,
    direction = direction,
    force = character.force,
    character = character,
    raise_built = true,
    create_build_effect_smoke = true
  })
  if not entity then
    inventory.insert({name = item_name, count = 1})
    V.fail("CREATE_FAILED", "Factorio refused entity placement")
  end

  local result = E.summary(entity)
  S.emit("bot.placed", {id = params.id, entity = result, item = item_name})
  return result
end

function M.rotate(params)
  local _, character = R.resolve(params)
  local target = resolve_target(params.unit_number)
  require_reach(character, target)
  local success = target.rotate({reverse = params.reverse == true})
  if not success then V.fail("ENGINE_ERROR", "entity rotation failed") end
  local result = E.summary(target)
  S.emit("bot.rotated", {id = params.id, entity = result})
  return result
end

function M.enter_vehicle(params)
  local _, character = R.resolve(params)
  local vehicle = resolve_target(params.unit_number)
  require_reach(character, vehicle)
  local ok, problem = pcall(function() vehicle.set_driver(character) end)
  if not ok then V.fail("ENGINE_ERROR", "failed to enter vehicle: " .. tostring(problem)) end
  if character.vehicle ~= vehicle then V.fail("ENGINE_ERROR", "Factorio did not put bot into requested vehicle") end
  local result = E.summary(vehicle)
  S.emit("bot.vehicle_entered", {id = params.id, vehicle = result})
  return result
end

function M.leave_vehicle(params)
  local _, character = R.resolve(params)
  if not character.vehicle then V.fail("NOT_FOUND", "bot is not in a vehicle") end
  local vehicle = character.vehicle
  character.set_driving(false, true)
  if character.vehicle then V.fail("ENGINE_ERROR", "Factorio did not eject bot from vehicle") end
  local result = E.summary(vehicle)
  S.emit("bot.vehicle_left", {id = params.id, vehicle = result})
  return result
end

function M.drive(params)
  local bot, character = R.resolve(params)
  if not character.vehicle then V.fail("NOT_FOUND", "bot is not driving a vehicle") end
  local acceleration = V.integer(params.acceleration, "acceleration", 0, 3)
  local direction = V.integer(params.direction, "direction", 0, 2)
  local ticks = V.integer(params.ticks, "ticks", 1, 600)
  local action = {kind = "drive", acceleration = acceleration, direction = direction, until_tick = game.tick + ticks}
  character.riding_state = {acceleration = acceleration, direction = direction}
  set_action(bot, action)
  S.emit("bot.action", {id = bot.id, action = action})
  return action
end

function M.select_gun(params)
  local _, character = R.resolve(params)
  local index = V.integer(params.index, "index", 1, 255)
  character.selected_gun_index = index
  return {id = params.id, selected_gun_index = character.selected_gun_index}
end

function M.set_recipe(params)
  local _, character = R.resolve(params)
  local target = resolve_target(params.unit_number)
  require_reach(character, target)
  local recipe = V.string(params.recipe, "recipe")
  local ok, returned = pcall(function() return target.set_recipe(recipe) end)
  if not ok then V.fail("ENGINE_ERROR", "entity does not accept recipe changes: " .. tostring(returned)) end
  S.emit("bot.recipe_set", {id = params.id, unit_number = target.unit_number, recipe = recipe})
  return {id = params.id, unit_number = target.unit_number, recipe = recipe}
end

function M.stop(character)
  character.shooting_state = {state = defines.shooting.not_shooting, position = character.position}
  character.picking_state = false
  character.repair_state = {repairing = false, position = character.position}
  if character.vehicle then
    character.riding_state = {
      acceleration = defines.riding.acceleration.nothing,
      direction = defines.riding.direction.straight
    }
  end
end

function M.tick_action(bot, character, action)
  if action.kind == "pickup" then
    character.picking_state = true
    return true
  elseif action.kind == "attack" then
    local target = game.get_entity_by_unit_number(action.unit_number)
    if not target or not target.valid or target.surface.index ~= character.surface.index or not character.can_shoot(target, target.position) then
      return false
    end
    character.shooting_state = {state = defines.shooting.shooting_selected, position = target.position}
    return true
  elseif action.kind == "repair" then
    local target = game.get_entity_by_unit_number(action.unit_number)
    if not target or not target.valid or not character.can_reach_entity(target) then return false end
    character.repair_state = {repairing = true, position = target.position}
    return true
  elseif action.kind == "drive" then
    if not character.vehicle then return false end
    character.riding_state = {acceleration = action.acceleration, direction = action.direction}
    return true
  end
  return nil
end

return M
