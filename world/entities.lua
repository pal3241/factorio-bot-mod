local V = require("bridge.validate")
local SpaceAge = require("space_age.queries")
local M = {}

---@param entity LuaEntity
---@return EntitySummary
function M.summary(entity)
  local ghost_name = entity.type == "entity-ghost" and entity.ghost_name or nil
  return {
    unit_number = entity.unit_number, name = entity.name, type = entity.type,
    position = entity.position, surface = entity.surface.name, force = entity.force.name,
    direction = entity.direction, quality = entity.quality.name,
    health = entity.health, max_health = entity.max_health, status = entity.status, ghost_name = ghost_name,
    bounding_box = entity.bounding_box
  }
end

---@param surface LuaSurface
---@param area BoundingBox
---@return LuaEntity[]
function M.scan(surface, area)
  local entities = surface.find_entities_filtered({area = area, limit = 16385})
  if #entities > 16384 then V.fail("AREA_TOO_DENSE", "more than 16384 entities; reduce area") end
  table.sort(entities, function(a, b)
    if a.position.y ~= b.position.y then return a.position.y < b.position.y end
    if a.position.x ~= b.position.x then return a.position.x < b.position.x end
    if a.name ~= b.name then return a.name < b.name end
    return (a.unit_number or 0) < (b.unit_number or 0)
  end)
  return entities
end

---@param entity LuaEntity
---@return InventoryView[]
function M.inventories(entity)
  local rows = {}
  for index = 1, entity.get_max_inventory_index() do
    local inventory = entity.get_inventory(index)
    if inventory then
      rows[#rows + 1] = {index = index, slots = #inventory, contents = inventory.get_contents()}
    end
  end
  return rows
end

---@param entity LuaEntity
---@return EntityDetail
function M.detail(entity)
  local row = M.summary(entity)
  row.inventories = M.inventories(entity)
  row.energy_j = entity.energy
  row.buffer_capacity_j = entity.electric_buffer_size
  row.electric_network_id = entity.electric_network_id
  row.fluids = entity.get_fluid_contents()
  row.collision_mask = entity.prototype.collision_mask
  if entity.type == "resource" then row.amount = entity.amount end
  if entity.type == "assembling-machine" or entity.type == "furnace" or entity.type == "rocket-silo" then
    local recipe = entity.get_recipe()
    row.machine = {recipe = recipe and recipe.name, progress = entity.crafting_progress,
      speed = entity.crafting_speed, products_finished = entity.products_finished, crafting = entity.is_crafting()}
  end
  if entity.type == "mining-drill" then
    row.mining_target = entity.mining_target and M.summary(entity.mining_target)
  end
  if entity.type == "inserter" then
    local stack = entity.held_stack
    row.inserter = {pickup_position = entity.pickup_position, drop_position = entity.drop_position,
      held = stack.valid_for_read and {name = stack.name, count = stack.count, quality = stack.quality.name} or nil}
  end
  if entity.type == "transport-belt" or entity.type == "underground-belt" or entity.type == "splitter" then
    row.belt = {speed_tiles_per_tick = entity.prototype.belt_speed, lines = {}}
    for index = 1, entity.get_max_transport_line_index() do
      row.belt.lines[#row.belt.lines + 1] = {index = index, contents = entity.get_transport_line(index).get_contents()}
    end
  end
  if entity.burner then
    row.burner = {remaining_burning_fuel_j = entity.burner.remaining_burning_fuel,
      currently_burning = entity.burner.currently_burning and entity.burner.currently_burning.name}
  end
  SpaceAge.entity_detail(entity, row)
  if entity.type == "entity-ghost" then
    row.ghost = {ghost_name = entity.ghost_name, construction_registered = entity.is_registered_for_construction(),
      required_items = entity.item_requests}
  end
  return row
end

---@param params EntityQuery
---@return LuaEntity
function M.resolve(params)
  local surface = game.get_surface(V.string(params.surface, "surface"))
  if not surface then V.fail("NOT_FOUND", "surface does not exist") end
  local name = V.string(params.name, "name")
  local position = V.position(params.position)
  local unit = V.integer(params.unit_number, "unit_number", 0, 4294967295)
  for _, entity in ipairs(surface.find_entities_filtered({position = position, radius = 0.01, name = name, limit = 64})) do
    if (entity.unit_number or 0) == unit then return entity end
  end
  V.fail("NOT_FOUND", "entity locator no longer matches; refresh the area query")
end

---@param params AreaQuery
---@return Page<EntitySummary>
function M.query(params)
  local surface, _, area = V.context(params)
  local rows = {}
  for _, entity in ipairs(M.scan(surface, area)) do rows[#rows + 1] = M.summary(entity) end
  return V.page(rows, params)
end

return M
