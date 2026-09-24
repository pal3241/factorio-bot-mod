local V = require("bridge.validate")
local M = {}

local function get(object, key)
  local ok, value = pcall(function() return object[key] end)
  if ok then return value end
  return nil
end

local function ref_name(value)
  if not value then return nil end
  local ok, name = pcall(function() return value.name end)
  if ok then return name end
  return nil
end

local function sorted_page(rows, params)
  table.sort(rows, function(a, b) return a.name < b.name end)
  return V.page(rows, params)
end

local function surface_conditions(proto)
  local rows = {}
  local conditions = get(proto, "surface_conditions")
  if conditions then
    for _, condition in pairs(conditions) do
      rows[#rows + 1] = {
        property = get(condition, "property"),
        min = get(condition, "min"),
        max = get(condition, "max")
      }
    end
  end
  return rows
end

local function ingredients_or_products(values)
  local rows = {}
  if not values then return rows end
  for _, value in pairs(values) do
    rows[#rows + 1] = {
      type = get(value, "type"),
      name = get(value, "name"),
      amount = get(value, "amount"),
      amount_min = get(value, "amount_min"),
      amount_max = get(value, "amount_max"),
      probability = get(value, "probability"),
      temperature = get(value, "temperature"),
      minimum_temperature = get(value, "minimum_temperature"),
      maximum_temperature = get(value, "maximum_temperature")
    }
  end
  return rows
end

local function catalogue_items(params)
  local rows = {}
  for name, proto in pairs(prototypes.item or {}) do
    rows[#rows + 1] = {
      name = name,
      type = get(proto, "type"),
      stack_size = get(proto, "stack_size"),
      weight = get(proto, "weight"),
      fuel_category = get(proto, "fuel_category"),
      fuel_value = get(proto, "fuel_value"),
      spoil_ticks = get(proto, "spoil_ticks"),
      spoil_result = ref_name(get(proto, "spoil_result")),
      plant_result = ref_name(get(proto, "plant_result")),
      hidden = get(proto, "hidden") or false
    }
  end
  return sorted_page(rows, params)
end

local function catalogue_fluids(params)
  local rows = {}
  for name, proto in pairs(prototypes.fluid or {}) do
    rows[#rows + 1] = {
      name = name,
      type = get(proto, "type"),
      default_temperature = get(proto, "default_temperature"),
      max_temperature = get(proto, "max_temperature"),
      fuel_value = get(proto, "fuel_value"),
      gas_temperature = get(proto, "gas_temperature"),
      hidden = get(proto, "hidden") or false
    }
  end
  return sorted_page(rows, params)
end

local function catalogue_entities(params)
  local rows = {}
  for name, proto in pairs(prototypes.entity or {}) do
    rows[#rows + 1] = {
      name = name,
      type = get(proto, "type"),
      max_health = get(proto, "max_health"),
      selectable_in_game = get(proto, "selectable_in_game"),
      weight = get(proto, "weight"),
      heating_energy = get(proto, "heating_energy"),
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
      type = get(proto, "type"),
      category = get(proto, "category"),
      energy = get(proto, "energy"),
      ingredients = ingredients_or_products(get(proto, "ingredients")),
      products = ingredients_or_products(get(proto, "products")),
      main_product = ref_name(get(proto, "main_product")),
      hidden = get(proto, "hidden") or false,
      allow_productivity = get(proto, "allow_productivity"),
      surface_conditions = surface_conditions(proto)
    }
  end
  return sorted_page(rows, params)
end

local function catalogue_technologies(params)
  local rows = {}
  for name, proto in pairs(prototypes.technology or {}) do
    local prerequisites = {}
    for _, prerequisite in pairs(get(proto, "prerequisites") or {}) do
      prerequisites[#prerequisites + 1] = prerequisite.name
    end
    table.sort(prerequisites)
    rows[#rows + 1] = {
      name = name,
      type = get(proto, "type"),
      prerequisites = prerequisites,
      research_trigger = get(proto, "research_trigger"),
      research_unit_count = get(proto, "research_unit_count"),
      research_unit_energy = get(proto, "research_unit_energy"),
      research_unit_ingredients = ingredients_or_products(get(proto, "research_unit_ingredients")),
      level = get(proto, "level"),
      max_level = get(proto, "max_level"),
      hidden = get(proto, "hidden") or false
    }
  end
  return sorted_page(rows, params)
end

local function catalogue_qualities(params)
  local rows = {}
  for name, proto in pairs(prototypes.quality or {}) do
    rows[#rows + 1] = {
      name = name,
      type = get(proto, "type"),
      level = get(proto, "level"),
      next_probability = get(proto, "next_probability"),
      beacon_power_usage_multiplier = get(proto, "beacon_power_usage_multiplier"),
      mining_drill_resource_drain_multiplier = get(proto, "mining_drill_resource_drain_multiplier")
    }
  end
  return sorted_page(rows, params)
end

local function catalogue_tiles(params)
  local rows = {}
  for name, proto in pairs(prototypes.tile or {}) do
    rows[#rows + 1] = {
      name = name,
      type = get(proto, "type"),
      layer = get(proto, "layer"),
      fluid = ref_name(get(proto, "fluid")),
      default_cover_tile = ref_name(get(proto, "default_cover_tile")),
      can_be_part_of_blueprint = get(proto, "can_be_part_of_blueprint")
    }
  end
  return sorted_page(rows, params)
end

local function catalogue_locations(params)
  local rows = {}
  for name, proto in pairs(prototypes.space_location or {}) do
    rows[#rows + 1] = {
      name = name,
      type = get(proto, "type"),
      distance = get(proto, "distance"),
      gravity_pull = get(proto, "gravity_pull"),
      asteroid_spawn_influence = get(proto, "asteroid_spawn_influence"),
      surface_properties = get(proto, "surface_properties") or {}
    }
  end
  return sorted_page(rows, params)
end

local function catalogue_connections(params)
  local rows = {}
  for name, proto in pairs(prototypes.space_connection or {}) do
    rows[#rows + 1] = {
      name = name,
      type = get(proto, "type"),
      from = ref_name(get(proto, "from")),
      to = ref_name(get(proto, "to")),
      length = get(proto, "length")
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
  if not provider then V.fail("INVALID_ARGUMENT", "unknown content category: " .. category) end
  return {category = category, page = provider(params)}
end

return M
