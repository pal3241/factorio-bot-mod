local V = require("bridge.validate")
local S = require("bridge.state")
local E = require("world.entities")
local Map = require("world.map")
local Resources = require("world.resources")
local Force = require("world.force")
local Networks = require("world.networks")
local Threats = require("world.threats")
local Players = require("world.players")
local Registry = require("bot.registry")
local Actions = require("bot.actions")
local Extended = require("bot.extended")
local Chat = require("bridge.chat")
local SpaceAge = require("space_age.queries")
local SpaceCatalog = require("space_age.catalog")
local M = {}

local queries = {
  surfaces = Map.surfaces, chunks = Map.chunks, terrain = Map.terrain,
  entities = E.query, resources = Resources.query, research = Force.research,
  recipes = Force.recipes, production = Force.production, electric = Networks.electric,
  logistics = Networks.logistics, trains = Networks.trains, threats = Threats.query,
  bots = Registry.list, players = Players.list, player = Players.get,
  ["player.location"] = Players.location, getlocation = Players.location, bot = Registry.get,
  shared = Registry.shared, craftable = Actions.craftable, ["bot.inventory"] = Extended.inventory, delta = S.delta,
  entity = function(params) return E.detail(E.resolve(params)) end
}
local space_age_queries = {
  ["space-age.capabilities"] = SpaceAge.capabilities,
  ["space-age.planets"] = SpaceAge.planets,
  ["space-age.locations"] = SpaceAge.locations,
  ["space-age.connections"] = SpaceAge.connections,
  ["space-age.platforms"] = SpaceAge.platforms,
  ["space-age.platform"] = SpaceAge.platform,
  ["space-age.snapshot"] = SpaceAge.snapshot,
  ["space-age.content-categories"] = SpaceCatalog.categories,
  ["space-age.content-summary"] = SpaceCatalog.summary,
  ["space-age.content"] = SpaceCatalog.query
}
local mutations = {
  ['bot.create'] = Registry.create, ['bot.destroy'] = Registry.destroy,
  ['bot.walk'] = Actions.walk, ['bot.stop'] = Actions.stop, ['bot.mine'] = Actions.mine,
  ['bot.craft'] = Actions.craft, ['bot.build-ghost'] = Actions.build_ghost,
  ['bot.transfer'] = Extended.transfer, ['bot.equip'] = Extended.equip, ['bot.unequip'] = Extended.unequip,
  ['bot.drop'] = Extended.drop,
  ['bot.pickup'] = Extended.pickup, ['bot.attack'] = Extended.attack,
  ['bot.repair'] = Extended.repair, ['bot.place'] = Extended.place,
  ['bot.rotate'] = Extended.rotate, ['bot.enter-vehicle'] = Extended.enter_vehicle,
  ['bot.leave-vehicle'] = Extended.leave_vehicle, ['bot.drive'] = Extended.drive,
  ['bot.select-gun'] = Extended.select_gun, ['bot.set-recipe'] = Extended.set_recipe,
  ['shared.write'] = Registry.write_shared, ['chat.send'] = Chat.send
}
local watchable = {entities = true, entity = true, bot = true, chunks = true, resources = true, electric = true, logistics = true,
  threats = true, research = true, bots = true, production = true, trains = true,
  ["space-age.platforms"] = true, ["space-age.planets"] = true}

---@param topic string
---@param query QueryParams
---@return SensorView, string
local function sample_query(topic, query)
  local query_fn = queries[topic] or space_age_queries[topic]
  if not query_fn then V.fail("INVALID_ARGUMENT", "unsupported watch topic") end
  local result = query_fn(query)
  if result.next_offset then V.fail("WATCH_TOO_LARGE", "subscription must fit in one page; reduce area") end
  local encoded = helpers.table_to_json(result)
  if #encoded > 131072 then V.fail("WATCH_TOO_LARGE", "subscription exceeds 128 KiB; reduce area") end
  return result, encoded
end

---@param params AreaQuery
---@return SnapshotView
function M.snapshot(params)
  V.context(params)
  return {scope = "bounded-area", chunks = Map.chunks(params), entities = E.query(params),
    resources = Resources.query(params), electric = Networks.electric(params),
    logistics = Networks.logistics(params), threats = Threats.query(params),
    research = Force.research(params), bots = Registry.list(params), players = Players.list(params),
    production = Force.production(params), trains = Networks.trains(params)}
end

---@param params WatchQuery
---@return WatchResult
function M.watch(params)
  local id = V.string(params.id, "id")
  local topic = V.string(params.topic, "topic")
  if not watchable[topic] then V.fail("INVALID_ARGUMENT", "topic does not support subscriptions") end
  local interval = V.integer(params.interval, "interval", 120, 3600)
  local query = V.object(params.query, "query")
  V.integer(query.offset, "query.offset", 0, 0)
  V.integer(query.limit, "query.limit", 256, 256)
  if not S.get().watches[id] and #V.keys(S.get().watches) >= 8 then V.fail("LIMIT", "at most 8 subscriptions") end
  local initial, encoded = sample_query(topic, query)
  S.put("watches", id, {id = id, topic = topic, query = helpers.json_to_table(helpers.table_to_json(query)),
    interval = interval, next_tick = game.tick + interval, fingerprint = encoded})
  S.emit("watch.created", {id = id, topic = topic})
  return {id = id, initial = initial, interval = interval}
end

---@param params BotQuery
---@return IdentityResult
function M.unwatch(params)
  local id = V.string(params.id, "id")
  if not S.get().watches[id] then V.fail("NOT_FOUND", "subscription does not exist") end
  S.put("watches", id, nil)
  return {id = id}
end

---Perubahan kontinu diberitakan sebagai invalidasi; konsumen membaca ulang query terkait.
function M.sample()
  for _, id in ipairs(V.keys(S.get().watches)) do
    local watch = S.get().watches[id]
    if game.tick >= watch.next_tick then
      local ok, result, encoded = pcall(sample_query, watch.topic, watch.query)
      if not ok then
        S.emit("watch.error", {id = id, error = M.error(result)})
        S.put("watches", id, nil)
      else
        if encoded ~= watch.fingerprint then S.emit("watch.changed", {id = id, topic = watch.topic}) end
        S.put("watches", id, {id = id, topic = watch.topic, query = watch.query, interval = watch.interval,
          next_tick = game.tick + watch.interval, fingerprint = encoded})
      end
    end
  end
end

---@param problem string|BridgeError
---@return BridgeError
function M.error(problem)
  if type(problem) == "table" and type(problem.code) == "string" and type(problem.message) == "string" then
    return {code = problem.code, message = problem.message}
  end
  return {code = "ENGINE_ERROR", message = tostring(problem)}
end

---@param request BridgeRequest
---@return BridgeData
local function dispatch(request)
  V.object(request, "request")
  V.string(request.id, "id")
  if request.api_version ~= 1 and request.api_version ~= 2 then V.fail("VERSION_MISMATCH", "api_version must be 1 or 2") end
  local method = V.string(request.method, "method")
  local params = V.object(request.params, "params")
  S.consume_budget()
  if method == "capabilities" then
    return {mod_version = "0.5.0", api_version = 2, minimum_factorio = "2.0.77",
      query_methods = V.keys(queries), space_age_methods = V.keys(space_age_queries), action_methods = V.keys(mutations),
      additional_methods = {"snapshot", "watch", "unwatch", "capabilities"},
      actions_enabled = settings.global["fbot-enable-actions"].value,
      enums = {direction = defines.direction, entity_status = defines.entity_status,
        train_state = defines.train_state, inventory = defines.inventory,
        shooting = defines.shooting, riding_acceleration = defines.riding.acceleration,
        riding_direction = defines.riding.direction},
      limits = {area_side = 128, entities_scanned = 16384, page = 256, event_retention = 2048,
        subscriptions = 8, bots = 32, request_bytes = 8192, response_bytes = 1048576},
      observation = "trusted-server-omniscient", virtual_bot = "server-side-character-not-LuaPlayer",
      event_semantics = "ordered-invalidation-log-plus-sampled-subscriptions",
      space_age = SpaceAge.capabilities()}
  elseif method == "snapshot" then return M.snapshot(params)
  elseif method == "watch" then return M.watch(params)
  elseif method == "unwatch" then return M.unwatch(params)
  elseif queries[method] then return queries[method](params)
  elseif space_age_queries[method] then return space_age_queries[method](params)
  elseif mutations[method] then
    if not settings.global["fbot-enable-actions"].value then V.fail("ACTIONS_DISABLED", "enable runtime setting fbot-enable-actions before mutating world or shared state") end
    local result = mutations[method](params)
    return result
  end
  V.fail("UNKNOWN_METHOD", "unknown API method: " .. method)
end

---@param request BridgeRequest
---@return BridgeResponse
function M.request(request)
  local ok, result = pcall(dispatch, request)
  local id = type(request) == "table" and type(request.id) == "string" and string.sub(request.id, 1, 128) or nil
  local response_version = type(request) == "table" and (request.api_version == 1 or request.api_version == 2) and request.api_version or 1
  local envelope = {api_version = response_version, id = id, tick = game.tick, cursor = S.get().sequence, ok = ok}
  if ok then envelope.data = result else envelope.error = M.error(result) end
  return envelope
end

---@param payload string
---@return string
function M.json(payload)
  if type(payload) ~= "string" or #payload > 8192 then
    return helpers.table_to_json({api_version = 1, ok = false, error = {code = "INVALID_REQUEST", message = "request must be a JSON string of at most 8192 bytes"}})
  end
  local request = helpers.json_to_table(payload)
  if not request then
    return helpers.table_to_json({api_version = 1, ok = false, error = {code = "INVALID_JSON", message = "request is not valid JSON"}})
  end
  local response = M.request(request)
  local ok, encoded = pcall(helpers.table_to_json, response)
  if not ok then
    return helpers.table_to_json({api_version = 1, id = response.id, ok = false, error = M.error(encoded)})
  end
  if #encoded > 1048576 then
    return helpers.table_to_json({api_version = 1, id = response.id, ok = false,
      error = {code = "RESPONSE_TOO_LARGE", message = "response exceeds 1 MiB; reduce area or page limit"}})
  end
  return encoded
end

return M
