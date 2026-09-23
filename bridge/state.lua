local V = require("bridge.validate")
local M = {}

---Mengganti state milik mod hanya pada batas penyimpanan Factorio.
function M.initialize()
  if storage.fbot and storage.fbot.schema ~= 1 then
    V.fail("STORAGE_VERSION", "unsupported stored schema; restore a compatible mod/save")
  end
  if not storage.fbot then
    storage.fbot = {schema = 1, bots = {}, shared = {}, watches = {}, events = {}, sequence = 0, budget_tick = -1, budget_used = 0}
  end
end

---@return BridgeState
function M.get()
  if not storage.fbot then V.fail("NOT_INITIALIZED", "world bridge has not initialized") end
  return storage.fbot
end

---Mutasi dibatasi pada penyimpanan state milik mod.
---@param category 'bots'|'shared'|'watches'
---@param key string
---@param value BotRecord|SharedEntry|WatchRecord|nil
function M.put(category, key, value)
  M.get()[category][key] = value
end

function M.consume_budget()
  local state = M.get()
  if state.budget_tick ~= game.tick then state.budget_tick, state.budget_used = game.tick, 0 end
  if state.budget_used >= settings.global["fbot-query-budget"].value then
    V.fail("RATE_LIMIT", "per-tick request budget exhausted; retry after simulation advances")
  end
  state.budget_used = state.budget_used + 1
end

---@param kind string
---@param data EventPayload
function M.emit(kind, data)
  local state = M.get()
  state.sequence = state.sequence + 1
  state.events[(state.sequence - 1) % 2048 + 1] = {sequence = state.sequence, tick = game.tick, kind = kind, data = data}
end

---@param params DeltaQuery
---@return DeltaView
function M.delta(params)
  local state = M.get()
  local after = V.integer(params.after, "after", 0, state.sequence)
  local limit = V.integer(params.limit, "limit", 1, 256)
  local oldest = math.max(1, state.sequence - 2047)
  if after < oldest - 1 then V.fail("CURSOR_EXPIRED", "events evicted; take snapshot and restart from its cursor") end
  local rows = {}
  local last = math.min(state.sequence, after + limit)
  for index = after + 1, last do rows[#rows + 1] = state.events[(index - 1) % 2048 + 1] end
  return {items = rows, next_cursor = last, head_cursor = state.sequence, has_more = last < state.sequence}
end

return M
