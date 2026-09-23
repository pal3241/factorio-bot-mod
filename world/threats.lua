local V = require("bridge.validate")
local E = require("world.entities")
local M = {}

---@param params AreaQuery
---@return ThreatPage
function M.query(params)
  local surface, force, area = V.context(params)
  local centre = {x = (area.left_top.x + area.right_bottom.x) / 2, y = (area.left_top.y + area.right_bottom.y) / 2}
  local rows, hostile_forces = {}, {}
  for _, other in pairs(game.forces) do
    if force.is_enemy(other) then
      hostile_forces[#hostile_forces + 1] = {name = other.name, evolution = other.get_evolution_factor(surface)}
    end
  end
  table.sort(hostile_forces, function(a, b) return a.name < b.name end)
  for _, entity in ipairs(E.scan(surface, area)) do
    if force.is_enemy(entity.force) then
      local row = E.summary(entity)
      row.distance_from_area_centre = math.sqrt((entity.position.x - centre.x)^2 + (entity.position.y - centre.y)^2)
      row.pollution_at_position = surface.get_pollution(entity.position)
      row.attack_parameters = entity.prototype.attack_parameters
      row.resistances = entity.prototype.resistances
      row.absorptions_to_join_attack = entity.prototype.absorptions_to_join_attack
      row.is_military_target = entity.is_military_target
      rows[#rows + 1] = row
    end
  end
  local page = V.page(rows, params)
  page.hostile_forces = hostile_forces
  page.pollution_at_centre = surface.get_pollution(centre)
  page.peaceful_mode = surface.peaceful_mode
  page.scope = "observed-area; no attack prediction"
  return page
end

return M
