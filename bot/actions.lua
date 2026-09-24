local V = require("bridge.validate")
local S = require("bridge.state")
local R = require("bot.registry")
local Extended = require("bot.extended")
local M = {}

---@param bot BotRecord
---@param action ActionView|nil
local function set_action(bot, action)
  S.put("bots", bot.id, {id = bot.id, network = bot.network, entity = bot.entity, created_tick = bot.created_tick, action = action})
end

---@param params WalkQuery
---@return ActionView
function M.walk(params)
  local bot = R.resolve(params)
  local direction = V.integer(params.direction, "direction", 0, 15)
  if direction % 2 ~= 0 then V.fail("INVALID_ARGUMENT", "walking requires an eight-way direction: 0,2,4,6,8,10,12,14") end
  local ticks = V.integer(params.ticks, "ticks", 1, 600)
  local action = {kind = "walk", direction = direction, until_tick = game.tick + ticks}
  set_action(bot, action)
  S.emit("bot.action", {id = bot.id, action = action})
  return action
end

---@param params BotQuery
---@return IdentityResult
function M.stop(params)
  local bot, entity = R.resolve(params)
  entity.walking_state = {walking = false, direction = defines.direction.north}
  entity.mining_state = {mining = false}
  Extended.stop(entity)
  set_action(bot, nil)
  S.emit("bot.stopped", {id = bot.id})
  return {id = bot.id}
end

---@param params MineQuery
---@return ActionView
function M.mine(params)
  local bot, entity = R.resolve(params)
  local position = V.position(params.position)
  local ticks = V.integer(params.ticks, "ticks", 1, 600)
  entity.update_selected_entity(position)
  local target = entity.selected
  if not target or not target.valid or not target.minable or not entity.can_reach_entity(target) then
    V.fail("UNREACHABLE_TARGET", "no reachable minable entity at position")
  end
  local action = {kind = "mine", position = position, until_tick = game.tick + ticks}
  set_action(bot, action)
  S.emit("bot.action", {id = bot.id, action = action})
  return action
end

---@param params CraftableQuery
---@return CraftableResult
function M.craftable(params)
  local _, entity = R.resolve(params)
  local name = V.string(params.recipe, "recipe")
  local recipe = entity.force.recipes[name]
  if not recipe then V.fail("NOT_FOUND", "recipe does not exist: " .. name) end
  return {recipe = name, enabled = recipe.enabled, count = entity.get_craftable_count(name)}
end

---@param params CraftQuery
---@return CraftResult
function M.craft(params)
  local _, entity = R.resolve(params)
  local availability = M.craftable(params)
  local count = V.integer(params.count, "count", 1, 100)
  if not availability.enabled or availability.count < count then V.fail("NOT_CRAFTABLE", "recipe disabled or insufficient hand-crafting ingredients") end
  local started = entity.begin_crafting({recipe = availability.recipe, count = count, silent = true})
  if started == 0 then V.fail("CRAFT_FAILED", "Factorio refused hand crafting for this character/recipe") end
  S.emit("bot.crafting", {id = params.id, recipe = availability.recipe, started = started})
  return {started = started}
end

---@param params BuildGhostQuery
---@return BuildGhostResult
function M.build_ghost(params)
  local _, character = R.resolve(params)
  local name = V.string(params.name, "name")
  local position = V.position(params.position)
  local direction = V.integer(params.direction, "direction", 0, 15)
  if direction % 2 ~= 0 then V.fail("INVALID_ARGUMENT", "building requires an eight-way direction: 0,2,4,6,8,10,12,14") end
  local prototype = game.entity_prototypes[name]
  if not prototype then V.fail("NOT_FOUND", "entity prototype does not exist: " .. name) end
  if not prototype.items_to_place_this or #prototype.items_to_place_this == 0 then
    V.fail("UNSUPPORTED_BUILDING", "entity has no placeable item and cannot be assigned to a constructor network: " .. name)
  end
  local surface = character.surface
  if not surface.is_chunk_generated({x = math.floor(position.x / 32), y = math.floor(position.y / 32)}) then
    V.fail("UNGENERATED_CHUNK", "machine ghost placement requires an already generated chunk")
  end
  local dx, dy = position.x - character.position.x, position.y - character.position.y
  if dx * dx + dy * dy > character.build_distance * character.build_distance then
    V.fail("UNREACHABLE_TARGET", "machine ghost position is outside the virtual character build distance")
  end
  for _, existing in ipairs(surface.find_entities_filtered({position = position, radius = 0.01, type = "entity-ghost", limit = 64})) do
    if existing.ghost_name == name and existing.force == character.force then
      V.fail("CONFLICT", "a matching machine ghost already exists at the requested position")
    end
  end
  if not surface.can_place_entity({name = "entity-ghost", inner_name = name, position = position, direction = direction,
    force = character.force, build_check_type = defines.build_check_type.manual_ghost}) then
    V.fail("COLLISION", "Factorio rejected the machine ghost at the requested position")
  end
  local ghost = surface.create_entity({name = "entity-ghost", inner_name = name, position = position, direction = direction,
    force = character.force, raise_built = true})
  if not ghost then V.fail("CREATE_FAILED", "Factorio refused to create the machine ghost") end
  local result = {id = params.id, ghost_unit_number = ghost.unit_number, name = ghost.ghost_name,
    surface = surface.name, force = character.force.name, position = ghost.position, direction = ghost.direction,
    construction_registered = ghost.is_registered_for_construction(), required_items = ghost.item_requests}
  S.emit("bot.build_ghost", result)
  return result
end

---Menjalankan hanya aksi karakter aktif, tanpa memindai dunia setiap tick.
function M.tick()
  for _, id in ipairs(V.keys(S.get().bots)) do
    local bot = S.get().bots[id]
    local entity, action = bot.entity, bot.action
    if action and entity and entity.valid then
      if not settings.global["fbot-enable-actions"].value or game.tick > action.until_tick then
        M.stop({id = id})
      elseif action.kind == "walk" then
        entity.mining_state = {mining = false}
        entity.walking_state = {walking = true, direction = action.direction}
      elseif action.kind == "mine" then
        entity.walking_state = {walking = false, direction = defines.direction.north}
        entity.update_selected_entity(action.position)
        if not entity.selected or not entity.can_reach_entity(entity.selected) then
          M.stop({id = id})
          S.emit("bot.target_lost", {id = id})
        else
          entity.mining_state = {mining = true, position = action.position}
        end
      else
        local running = Extended.tick_action(bot, entity, action)
        if running == false then
          M.stop({id = id})
          S.emit("bot.target_lost", {id = id, action = action.kind})
        end
      end
    elseif action then
      set_action(bot, nil)
      S.emit("bot.died", {id = id})
    end
  end
end

return M
