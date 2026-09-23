local V = require("bridge.validate")
local E = require("world.entities")
local M = {}
local supported = {['iron-ore'] = true, ['copper-ore'] = true, coal = true, stone = true, ['uranium-ore'] = true}

---@param name string
---@param x number
---@param y number
---@return string
local function key(name, x, y)
  return name .. ":" .. x .. ":" .. y
end

---@param params AreaQuery
---@return ResourcePage
function M.query(params)
  local surface, _, area = V.context(params)
  local cells, ordered, visited, patches = {}, {}, {}, {}
  for _, entity in ipairs(E.scan(surface, area)) do
    if entity.type == "resource" and supported[entity.name] then
      local x, y = math.floor(entity.position.x), math.floor(entity.position.y)
      local id = key(entity.name, x, y)
      if cells[id] then V.fail("UNSUPPORTED_RESOURCE_LAYOUT", "multiple resource entities occupy tile " .. id) end
      cells[id] = {entity = entity, x = x, y = y, id = id}
      ordered[#ordered + 1] = cells[id]
    end
  end
  for _, seed in ipairs(ordered) do
    if not visited[seed.id] then
      local queue, head, amount, count, sx, sy = {seed}, 1, 0, 0, 0, 0
      local minx, miny, maxx, maxy = seed.x, seed.y, seed.x + 1, seed.y + 1
      visited[seed.id] = true
      while head <= #queue do
        local cell = queue[head]
        head = head + 1
        amount, count = amount + cell.entity.amount, count + 1
        sx, sy = sx + cell.entity.position.x, sy + cell.entity.position.y
        minx, miny, maxx, maxy = math.min(minx, cell.x), math.min(miny, cell.y), math.max(maxx, cell.x + 1), math.max(maxy, cell.y + 1)
        for dx = -1, 1 do
          for dy = -1, 1 do
            local adjacent = key(seed.entity.name, cell.x + dx, cell.y + dy)
            if cells[adjacent] and not visited[adjacent] then
              visited[adjacent] = true
              queue[#queue + 1] = cells[adjacent]
            end
          end
        end
      end
      patches[#patches + 1] = {query_local_id = surface.index .. ":" .. seed.id, name = seed.entity.name,
        position = {x = sx / count, y = sy / count}, bounds = {left_top = {x = minx, y = miny}, right_bottom = {x = maxx, y = maxy}},
        tile_count = count, observed_amount = amount, estimated_amount = amount,
        touches_query_boundary = minx <= area.left_top.x or miny <= area.left_top.y or maxx >= area.right_bottom.x or maxy >= area.right_bottom.y}
    end
  end
  local page = V.page(patches, params)
  page.scope = "query-area-only"
  page.connectivity = "8-neighbour-tiles"
  return page
end

return M
