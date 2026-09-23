local M = {}

---@param code string
---@param message string
function M.fail(code, message)
  error({code = code, message = message}, 0)
end

---@param value number
---@param field string
---@param minimum number
---@param maximum number
---@return number
function M.number(value, field, minimum, maximum)
  if type(value) ~= "number" or value ~= value or value < minimum or value > maximum then
    M.fail("INVALID_ARGUMENT", field .. " must be a finite number in [" .. minimum .. ", " .. maximum .. "]")
  end
  return value
end

---@param value integer
---@param field string
---@param minimum integer
---@param maximum integer
---@return integer
function M.integer(value, field, minimum, maximum)
  M.number(value, field, minimum, maximum)
  if value % 1 ~= 0 then M.fail("INVALID_ARGUMENT", field .. " must be an integer") end
  return value
end

---@param value string
---@param field string
---@return string
function M.string(value, field)
  if type(value) ~= "string" or #value < 1 or #value > 128 then
    M.fail("INVALID_ARGUMENT", field .. " must be a nonempty string of at most 128 bytes")
  end
  return value
end

---@generic T
---@param value T
---@param field string
---@return T
function M.object(value, field)
  if type(value) ~= "table" then M.fail("INVALID_ARGUMENT", field .. " must be an object") end
  return value
end

---@param value MapPosition
---@return MapPosition
function M.position(value)
  M.object(value, "position")
  return {x = M.number(value.x, "position.x", -1000000, 1000000), y = M.number(value.y, "position.y", -1000000, 1000000)}
end

---@param value BoundingBox
---@return BoundingBox
function M.area(value)
  M.object(value, "area")
  local left = M.position(value.left_top)
  local right = M.position(value.right_bottom)
  if right.x <= left.x or right.y <= left.y or right.x - left.x > 128 or right.y - left.y > 128 then
    M.fail("INVALID_ARGUMENT", "area must have positive width/height, each at most 128 tiles")
  end
  return {left_top = left, right_bottom = right}
end

---@param params AreaQuery
---@return LuaSurface, LuaForce, BoundingBox
function M.context(params)
  local surface = game.get_surface(M.string(params.surface, "surface"))
  local force = game.forces[M.string(params.force, "force")]
  if not surface then M.fail("NOT_FOUND", "surface does not exist: " .. params.surface) end
  if not force then M.fail("NOT_FOUND", "force does not exist: " .. params.force) end
  return surface, force, M.area(params.area)
end

---@generic T
---@param collection table<string, T>
---@return string[]
function M.keys(collection)
  local result = {}
  for name in pairs(collection) do result[#result + 1] = name end
  table.sort(result)
  return result
end

---@generic T
---@param rows T[]
---@param params PageQuery
---@return Page<T>
function M.page(rows, params)
  local offset = M.integer(params.offset, "offset", 0, 1000000)
  local limit = M.integer(params.limit, "limit", 1, 256)
  local items = {}
  for i = offset + 1, math.min(#rows, offset + limit) do items[#items + 1] = rows[i] end
  return {items = items, total = #rows, next_offset = offset + #items < #rows and offset + #items or nil}
end

return M
