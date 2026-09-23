local V = require("bridge.validate")
local E = require("world.entities")
local M = {}

---@param statistics LuaFlowStatistics
---@param names string[]
---@param category string
---@return number
local function watts(statistics, names, category)
  local value = 0
  for _, name in ipairs(names) do
    value = value + statistics.get_flow_count({name = name, category = category,
      precision_index = defines.flow_precision_index.five_seconds}) * 60
  end
  return value
end

---@param params AreaQuery
---@return Page<ElectricView>
function M.electric(params)
  local surface, force, area = V.context(params)
  local networks, rows = {}, {}
  for _, entity in ipairs(E.scan(surface, area)) do
    local id = entity.electric_network_id
    if id and entity.force == force then
      local row = networks[id]
      if not row then
        row = {network_id = id, members_observed = 0, generators = {}, accumulators = {},
          observed_storage_j = 0, observed_storage_capacity_j = 0, observed_nominal_generation_w = 0,
          member_scope = "query-area-only", satisfaction = {available = false,
            reason = "Factorio 2.0 does not expose network unmet demand; consumption/production is not satisfaction"}}
        networks[id], rows[#rows + 1] = row, row
      end
      row.members_observed = row.members_observed + 1
      if entity.type == "electric-pole" and not row.measured then
        local statistics = entity.electric_network_statistics
        row.measured = {scope = "whole-network", window_seconds = 5,
          production_w = watts(statistics, V.keys(statistics.input_counts), "input"),
          consumption_w = watts(statistics, V.keys(statistics.output_counts), "output"),
          includes_accumulator_flows = true}
      end
      if entity.type == "accumulator" then
        row.observed_storage_j = row.observed_storage_j + entity.energy
        row.observed_storage_capacity_j = row.observed_storage_capacity_j + entity.electric_buffer_size
        row.accumulators[#row.accumulators + 1] = {unit_number = entity.unit_number,
          energy_j = entity.energy, capacity_j = entity.electric_buffer_size}
      elseif entity.type == "generator" or entity.type == "solar-panel" or entity.type == "burner-generator" or entity.type == "electric-energy-interface" then
        local nominal = entity.prototype.get_max_energy_production(entity.quality) * 60
        if entity.type == "electric-energy-interface" then nominal = entity.power_production * 60 end
        row.observed_nominal_generation_w = row.observed_nominal_generation_w + nominal
        row.generators[#row.generators + 1] = {unit_number = entity.unit_number, name = entity.name,
          status = entity.status, nominal_w = nominal, energy_buffer_j = entity.energy,
          fluids = entity.get_fluid_contents()}
      end
    end
  end
  table.sort(rows, function(a, b) return a.network_id < b.network_id end)
  return V.page(rows, params)
end

---@param params AreaQuery
---@return Page<LogisticView>
function M.logistics(params)
  local surface, force, area = V.context(params)
  local seen, rows = {}, {}
  for _, entity in ipairs(E.scan(surface, area)) do
    if entity.type == "roboport" and entity.force == force then
      local network = entity.logistic_network
      if network and not seen[network.network_id] then
        seen[network.network_id] = true
        local cells = {}
        if #network.cells > 256 then V.fail("NETWORK_TOO_LARGE", "logistic network exceeds 256 cells") end
        for _, cell in ipairs(network.cells) do
          cells[#cells + 1] = {owner = M.owner(cell.owner), logistic_radius = cell.logistic_radius,
            construction_radius = cell.construction_radius, charging = cell.charging_robot_count,
            awaiting_charge = cell.to_charge_robot_count}
        end
        table.sort(cells, function(a, b) return a.owner.unit_number < b.owner.unit_number end)
        rows[#rows + 1] = {network_id = network.network_id, scope = "whole-network-intersecting-area",
          logistic_robots = network.all_logistic_robots, construction_robots = network.all_construction_robots,
          available_logistic_robots = network.available_logistic_robots,
          available_construction_robots = network.available_construction_robots,
          contents = network.get_contents(), cells = cells}
      end
    end
  end
  table.sort(rows, function(a, b) return a.network_id < b.network_id end)
  return V.page(rows, params)
end

---@param entity LuaEntity
---@return EntityIdentity
function M.owner(entity)
  return {unit_number = entity.unit_number, name = entity.name, position = entity.position}
end

---@param params AreaQuery
---@return Page<TrainView>
function M.trains(params)
  local surface, force, area = V.context(params)
  local rows, seen = {}, {}
  local rolling = {locomotive = true, ['cargo-wagon'] = true, ['fluid-wagon'] = true, ['artillery-wagon'] = true}
  for _, entity in ipairs(E.scan(surface, area)) do
    if rolling[entity.type] and entity.force == force then
      local train = entity.train
      if not seen[train.id] then
        seen[train.id] = true
        local carriages = {}
        for _, carriage in ipairs(train.carriages) do carriages[#carriages + 1] = M.owner(carriage) end
        rows[#rows + 1] = {id = train.id, state = train.state, speed_tiles_per_tick = train.speed,
          manual_mode = train.manual_mode, has_path = train.has_path, carriages = carriages,
          station = train.station and M.owner(train.station), schedule = train.schedule,
          contents = train.get_contents(), fluids = train.get_fluid_contents()}
      end
    end
  end
  table.sort(rows, function(a, b) return a.id < b.id end)
  return V.page(rows, params)
end

return M
