local V = require("bridge.validate")
local S = require("bridge.state")
local E = require("world.entities")
local M = {}

---@param params BotQuery
---@return BotRecord, LuaEntity
function M.resolve(params)
  local bot = S.get().bots[V.string(params.id, "id")]
  if not bot then V.fail("NOT_FOUND", "bot is not registered: " .. params.id) end
  local entity = bot.entity
  if not entity or not entity.valid then V.fail("BOT_DEAD", "bot character no longer exists; remove registry entry and recreate") end
  return bot, entity
end

---@param params PageQuery
---@return Page<BotView>
function M.list(params)
  local rows = {}
  for _, id in ipairs(V.keys(S.get().bots)) do
    local bot = S.get().bots[id]
    local alive = bot.entity and bot.entity.valid
    rows[#rows + 1] = {id = id, network = bot.network, alive = alive, created_tick = bot.created_tick,
      entity = alive and E.summary(bot.entity) or nil, action = bot.action}
  end
  return V.page(rows, params)
end

---@param params PageQuery
---@return Page<PlayerView>
function M.players(params)
  local rows = {}
  for _, player in pairs(game.players) do
    rows[#rows + 1] = {index = player.index, name = player.name, connected = player.connected,
      force = player.force.name, surface = player.surface.name, position = player.position,
      controller_type = player.controller_type, character = player.character and E.summary(player.character)}
  end
  table.sort(rows, function(a, b) return a.index < b.index end)
  return V.page(rows, params)
end

---@param params BotQuery
---@return BotDetail
function M.get(params)
  local bot, entity = M.resolve(params)
  return {id = bot.id, network = bot.network, entity = E.detail(entity), crafting_queue = entity.crafting_queue,
    crafting_progress = entity.crafting_queue_progress, action = bot.action}
end

---@param params CreateBotQuery
---@return IdentityResult
function M.create(params)
  local id, network = V.string(params.id, "id"), V.string(params.network, "network")
  if S.get().bots[id] then V.fail("CONFLICT", "bot id already exists: " .. id) end
  if #V.keys(S.get().bots) >= 32 then V.fail("LIMIT", "at most 32 virtual bots are supported") end
  local surface = game.get_surface(V.string(params.surface, "surface"))
  local force = game.forces[V.string(params.force, "force")]
  if not surface or not force then V.fail("NOT_FOUND", "surface or force does not exist") end
  local position = V.position(params.position)
  if not surface.is_chunk_generated({x = math.floor(position.x / 32), y = math.floor(position.y / 32)}) then
    V.fail("UNGENERATED_CHUNK", "bot creation requires an already generated chunk")
  end
  if not surface.can_place_entity({name = "character", position = position, force = force}) then
    V.fail("COLLISION", "character cannot be placed at requested position")
  end
  local entity = surface.create_entity({name = "character", position = position, force = force, raise_built = true})
  if not entity then V.fail("CREATE_FAILED", "Factorio did not create the character") end
  S.put("bots", id, {id = id, network = network, entity = entity, created_tick = game.tick})
  S.emit("bot.created", {id = id, entity = E.summary(entity)})
  return {id = id, unit_number = entity.unit_number}
end

---@param params BotQuery
---@return IdentityResult
function M.destroy(params)
  local id = V.string(params.id, "id")
  local bot = S.get().bots[id]
  if not bot then V.fail("NOT_FOUND", "bot is not registered: " .. id) end
  if bot.entity and bot.entity.valid then
    if bot.entity.has_items_inside() or bot.entity.crafting_queue_size > 0 then
      V.fail("BOT_NOT_EMPTY", "empty all bot inventories and finish crafting before destroying it")
    end
    if not bot.entity.destroy({raise_destroy = true}) then V.fail("DESTROY_FAILED", "Factorio refused character destruction") end
  end
  S.put("bots", id, nil)
  S.emit("bot.removed", {id = id})
  return {id = id}
end

---@param params SharedQuery
---@return Page<SharedEntry>
function M.shared(params)
  local network = V.string(params.network, "network")
  local rows = {}
  for _, key in ipairs(V.keys(S.get().shared)) do
    local entry = S.get().shared[key]
    if entry.network == network then rows[#rows + 1] = entry end
  end
  return V.page(rows, params)
end

---@param params SharedWriteQuery
---@return SharedEntry
function M.write_shared(params)
  local network, key = V.string(params.network, "network"), V.string(params.key, "key")
  local value = V.string(params.value, "value")
  local expected = V.integer(params.expected_revision, "expected_revision", 0, 2147483647)
  local id = #network .. ":" .. network .. key
  local previous = S.get().shared[id]
  if expected ~= (previous and previous.revision or 0) then V.fail("CONFLICT", "shared state revision changed; read before retry") end
  if not previous and #V.keys(S.get().shared) >= 256 then V.fail("LIMIT", "shared state is limited to 256 keys") end
  local entry = {network = network, key = key, value = value, revision = expected + 1, tick = game.tick}
  S.put("shared", id, entry)
  S.emit("shared.changed", entry)
  return entry
end

return M
