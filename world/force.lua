local V = require("bridge.validate")
local M = {}

---@param params ForceQuery
---@return LuaForce
local function force_for(params)
  local force = game.forces[V.string(params.force, "force")]
  if not force then V.fail("NOT_FOUND", "force does not exist: " .. params.force) end
  return force
end

---@param params ForceQuery
---@return ResearchPage
function M.research(params)
  local force, rows = force_for(params), {}
  for _, name in ipairs(V.keys(force.technologies)) do
    local tech = force.technologies[name]
    local ready = tech.enabled and not tech.researched and force.research_enabled
    local prerequisites = {}
    for _, prerequisite in ipairs(V.keys(tech.prerequisites)) do
      local parent = tech.prerequisites[prerequisite]
      prerequisites[#prerequisites + 1] = {name = parent.name, researched = parent.researched}
      ready = ready and parent.researched
    end
    rows[#rows + 1] = {name = name, researched = tech.researched, enabled = tech.enabled,
      available = ready, prerequisites = prerequisites, level = tech.level,
      progress = force.current_research == tech and force.research_progress or tech.saved_progress,
      unit_count = tech.research_unit_count, unit_energy_ticks = tech.research_unit_energy,
      ingredients = tech.research_unit_ingredients, trigger = tech.prototype.research_trigger}
  end
  local page = V.page(rows, params)
  page.current = force.current_research and force.current_research.name
  page.progress = force.research_progress
  page.queue = {}
  for _, tech in ipairs(force.research_queue or {}) do page.queue[#page.queue + 1] = tech.name end
  return page
end

---@param params ForceQuery
---@return Page<RecipeView>
function M.recipes(params)
  local force, rows = force_for(params), {}
  for _, name in ipairs(V.keys(force.recipes)) do
    local recipe = force.recipes[name]
    rows[#rows + 1] = {name = name, enabled = recipe.enabled, hidden = recipe.hidden,
      category = recipe.category, energy_seconds = recipe.energy, ingredients = recipe.ingredients,
      products = recipe.products, surface_conditions = recipe.prototype.surface_conditions}
  end
  return V.page(rows, params)
end

---@param params AreaQuery
---@return ProductionPage
function M.production(params)
  local surface, force = V.context(params)
  local rows = {}
  local statistics = {
    {kind = "item", value = force.get_item_production_statistics(surface)},
    {kind = "fluid", value = force.get_fluid_production_statistics(surface)}
  }
  for _, group in ipairs(statistics) do
    local names = {}
    for name in pairs(group.value.input_counts) do names[name] = true end
    for name in pairs(group.value.output_counts) do names[name] = true end
    for _, name in ipairs(V.keys(names)) do
      rows[#rows + 1] = {kind = group.kind, name = name,
        produced_total = group.value.get_input_count(name), consumed_total = group.value.get_output_count(name),
        produced_per_minute = group.value.get_flow_count({name = name, category = "input", precision_index = defines.flow_precision_index.one_minute}),
        consumed_per_minute = group.value.get_flow_count({name = name, category = "output", precision_index = defines.flow_precision_index.one_minute})}
    end
  end
  local page = V.page(rows, params)
  page.scope = "force-surface"
  page.quality_semantics = "engine-name-aggregates"
  return page
end

return M
