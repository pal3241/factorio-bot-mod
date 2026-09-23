local V = require("bridge.validate")
local M = {}

---@param params PageQuery
---@return Page<SurfaceView>
function M.surfaces(params)
  local rows = {}
  for _, surface in pairs(game.surfaces) do
    rows[#rows + 1] = {index = surface.index, name = surface.name, daytime = surface.daytime,
      darkness = surface.darkness, peaceful_mode = surface.peaceful_mode,
      solar_power_multiplier = surface.solar_power_multiplier, pollutant_type = surface.pollutant_type}
  end
  table.sort(rows, function(a, b) return a.index < b.index end)
  return V.page(rows, params)
end

---@param params AreaQuery
---@return Page<ChunkView>
function M.chunks(params)
  local surface, force, area = V.context(params)
  local rows = {}
  for y = math.floor(area.left_top.y / 32), math.ceil(area.right_bottom.y / 32) - 1 do
    for x = math.floor(area.left_top.x / 32), math.ceil(area.right_bottom.x / 32) - 1 do
      local position = {x = x, y = y}
      rows[#rows + 1] = {x = x, y = y, generated = surface.is_chunk_generated(position),
        charted = force.is_chunk_charted(surface, position), visible = force.is_chunk_visible(surface, position),
        pollution = surface.get_pollution({x = x * 32 + 16, y = y * 32 + 16})}
    end
  end
  return V.page(rows, params)
end

---@param params AreaQuery
---@return TerrainPage
function M.terrain(params)
  local surface, force, area = V.context(params)
  local offset = V.integer(params.offset, "offset", 0, 1000000)
  local limit = V.integer(params.limit, "limit", 1, 256)
  local x0, y0 = math.floor(area.left_top.x), math.floor(area.left_top.y)
  local width, height = math.ceil(area.right_bottom.x) - x0, math.ceil(area.right_bottom.y) - y0
  local rows = {}
  for index = offset, math.min(width * height - 1, offset + limit - 1) do
    local x, y = x0 + index % width, y0 + math.floor(index / width)
    local generated = surface.is_chunk_generated({x = math.floor(x / 32), y = math.floor(y / 32)})
    local tile = surface.get_tile(x, y)
    rows[#rows + 1] = {position = {x = x, y = y}, name = tile.name, generated = generated,
      collision_mask = tile.prototype.collision_mask,
      character_placeable = generated and surface.can_place_entity({name = "character", position = {x = x + 0.5, y = y + 0.5}, force = force})}
  end
  return {items = rows, total = width * height, next_offset = offset + #rows < width * height and offset + #rows or nil,
    passability_semantics = "character-placement-at-tile-centre; not a path guarantee"}
end

return M
