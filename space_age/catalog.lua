local V = require("bridge.validate")
local M = {}

local function sorted_page(rows, params)
  table.sort(rows, function(a, b) return a.name < b.name end)
  return V.page(rows, params)
end

local function surface_conditions(proto)
  local rows = {}
  if proto and proto.surface_conditions then
    for _, condition in pairs(proto.surface_conditions) do
      rows[#rows + 1] = {
        property = condition.property,
        min = condition.min,
        max = condition.max
      }
    end
  end
  return rows
end

local function catalogue_items(params)
  local rows = {}
  for name, proto in pairs(prototypes.item or {}) do
    rows[#rows + 1] = {
      name = name,
      type = proto.type,
      stack_size = proto.stack_size,
      weight = proto.weight,
      fuel_category = proto.fuel_category,
      fuel_value = proto.fuel_value,
      spoil_ticks = proto.spoil_ticks,
      spoil_result = proto.spoil_result and proto.spoil_result.name or nil,
      plant_result = proto.plant_result and proto.plant_result.name or nil,
      rocket_launch_products = proto.rocket_launch_products or {},
      hidden = proto.hidden or false
    }
  end
  return sorted_page(rows, params)
end

local function catalogue_fluids(params)
  local rows = {}
  for name, proto in pairs(prototypes.fluid or {}) do
    rows[#rows + 1] = {
      name = name,
      type = proto.type,
      default_temperature = proto.default_temperature,
      max_temperature = proto.max_temperature,
      fuel_value = proto.fuel_value,
      gas_temperature = proto.gas_temperature,
      hidden = proto.hidden or false
    }
  end
  return sorted_page(rows, params)
end

local function catalogue_entities(params)
  local rows = {}
  for name, proto in pairs(prototypes.entity or {}) do
    rows[#rows + 1] = {
      name = name,
      type = proto.type,
      max_health = proto.max_health,
      selectable_in_game = proto.selectable_in_game,
      weight = proto.weight,
      heating_energy = proto.heating_energy,
      allow_copy_paste = proto.allow_copy_paste,
      protected_from_tile_building = proto.protected_from_tile_building,
      surface_conditions = surface_conditions(proto)
    }
  end
  return sorted_page(rows, params)
end

local function catalogue_recipes(params)
  local rows = {}
  for name, proto in pairs(prototypes.recipe or {}) do
    rows[#rows + 1] = {
      name = name,
      type = proto.type,
      category = proto.category,
      energy = proto.energy,
      ingredients = proto.ingredients or {},
      products = proto.products or {},
      main_product = proto.main_product and proto.main_product.name or nil,
      hidden = proto.hidden or false,
      allow_productivity = proto.allow_productivity,
      surface_conditions = surface_conditions(proto)
    }
  end
  return sorted_page(rows, params)
end

local function catalogue_technologies(params)
  local rows = {}
  for name, proto in pairs(prototypes.technology or {}) do
    local prerequisites = {}
    for _, prerequisite in pairs(proto.prerequisites or {}) do
      prerequisites[#prerequisites + 1] = prerequisite.name
    end
    table.sort(prerequisites)
    rows[#rows + 1] = {
      name = name,
      type = proto.type,
      prerequisites = prerequisites,
      research_trigger = proto.research_trigger,
      research_unit_count = proto.research_unit_count,
      research_unit_energy = proto.research_unit_energy,
      research_unit_ingredients = proto.research_unit_ingredients or {},
      level = proto.level,
      max_level = proto.max_level,
      hidden = proto.hidden or false
    }
  end
  return sorted_page(rows, params)
end

local function catalogue_qualities(params)
  local rows = {}
  for name, proto in pairs(prototypes.quality or {}) do
    rows[#rows + 1] = {
      name = name,
      type = proto.type,
      level = proto.level,
      next_probability = proto.next_probability,
      beacon_power_usage_multiplier = proto.beacon_power_usage_multiplier,
      mining_drill_resource_drain_multiplier = proto.mining_drill_resource_drain_multiplier
    }
  end
  return sorted_page(rows, params)
end

local function catalogue_tiles(params)
  local rows = {}
  for name, proto in pairs(prototypes.tile or {}) do
    rows[#rows + 1] = {
      name = name,
      type = proto.type,
      layer = proto.layer,
      fluid = proto.fluid and proto.fluid.name or nil,
      default_cover_tile = proto.default_cover_tile and proto.default_cover_tile.name or nil,
      can_be_part_of_blueprint = proto.can_be_part_of_blueprint
    }
  end
  return sorted_page(rows, params)
end

local function catalogue_locations(params)
  local rows = {}
  for name, proto in pairs(prototypes.space_location or {}) do
    rows[#rows + 1] = {
      name = name,
      type = proto.type,
      distance = proto.distance,
      gravity_pull = proto.gravity_pull,
      asteroid_spawn_influence = proto.asteroid_spawn_influence,
      surface_properties = proto.surface_properties or {}
    }
  end
  return sorted_page(rows, params)
end

local function catalogue_connections(params)
  local rows = {}
  for name, proto in pairs(prototypes.space_connection or {}) do
    rows[#rows + 1] = {
      name = name,
      type = proto.type,
      from = proto.from and proto.from.name or nil,
      to = proto.to and proto.to.name or nil,
      length = proto.length
    }
  end
  return sorted_page(rows, params)
end

local providers = {
  items = catalogue_items,
  fluids = catalogue_fluids,
  entities = catalogue_entities,
  recipes = catalogue_recipes,
  technologies = catalogue_technologies,
  qualities = catalogue_qualities,
  tiles = catalogue_tiles,
  ["space-locations"] = catalogue_locations,
  ["space-connections"] = catalogue_connections
}

function M.categories()
  local names = {}
  for name in pairs(providers) do names[#names + 1] = name end
  table.sort(names)
  return {items = names, total = #names}
end

function M.summary()
  local counts = {}
  for name, provider in pairs(providers) do
    local result = provider({offset = 0, limit = 1})
    counts[name] = result.total
  end
  return {
    expansion_active = script.active_mods["space-age"] ~= nil,
    quality_active = script.active_mods["quality"] ~= nil,
    elevated_rails_active = script.active_mods["elevated-rails"] ~= nil,
    counts = counts
  }
end

function M.query(params)
  local category = V.string(params.category, "category")
  local provider = providers[category]
  if not provider then
    V.fail("INVALID_ARGUMENT", "unknown content category: " .. category)
  end
  return {
    category = category,
    page = provider(params)
  }
end

return M
