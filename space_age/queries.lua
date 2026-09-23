local V = require("bridge.validate")
local M = {}

local function prototypes_available()
  return prototypes and prototypes.space_location and prototypes.space_connection
end

local function position(value)
  return {x = value.x, y = value.y}
end

local function location(value)
  if not value then return nil end
  return {name = value.name, type = value.type, position = position(value.position),
    distance = value.distance, gravity_pull = value.gravity_pull,
    asteroid_spawn_influence = value.asteroid_spawn_influence,
    surface_properties = value.surface_properties}
end

local function catalog_page(rows, params)
  table.sort(rows, function(a, b) return a.name < b.name end)
  return V.page(rows, params)
end

function M.capabilities()
  local available = prototypes_available() ~= nil and game.planets ~= nil
  local result = {available = available, api_version = 2,
    feature_set = {"planets", "space-platforms", "space-connections", "asteroid-chunks",
      "surface-properties", "cargo-pods", "platform-schedules", "cross-surface-snapshot"}}
  if available then
    result.expansion = "space-age"
  else
    result.limitation = "Space Age runtime prototypes are not active in this save"
  end
  return result
end

function M.locations(params)
  if not M.capabilities().available then return {items = {}, total = 0} end
  local rows = {}
  for name, proto in pairs(prototypes.space_location) do
    rows[#rows + 1] = location(proto)
  end
  return catalog_page(rows, params)
end

function M.connections(params)
  if not M.capabilities().available then return {items = {}, total = 0} end
  local rows = {}
  for name, proto in pairs(prototypes.space_connection) do
    rows[#rows + 1] = {name = name, from = proto.from.name, to = proto.to.name,
      length = proto.length}
  end
  return catalog_page(rows, params)
end

function M.planets(params)
  if not M.capabilities().available then return {items = {}, total = 0} end
  local rows = {}
  for name, planet in pairs(game.planets) do
    local proto = planet.prototype
    local platform_count = 0
    for _, force in pairs(game.forces) do
      for _, platform in pairs(force.platforms) do
        if platform.space_location and platform.space_location.name == name then platform_count = platform_count + 1 end
      end
    end
    rows[#rows + 1] = {name = name, surface = planet.surface and planet.surface.name or nil,
      surface_generated = planet.surface ~= nil,
      location = location(proto), pollutant_type = proto.pollutant_type and proto.pollutant_type.name or nil,
      entities_require_heating = proto.entities_require_heating,
      surface_properties = proto.surface_properties or {}, platform_count = platform_count}
  end
  return catalog_page(rows, params)
end

function M.platforms(params)
  if not M.capabilities().available then return {items = {}, total = 0} end
  local force_name = V.string(params.force, "force")
  local force = game.forces[force_name]
  if not force then V.fail("NOT_FOUND", "force does not exist: " .. force_name) end
  local rows = {}
  for index, platform in pairs(force.platforms) do
    local surface = platform.surface
    if not params.surface or params.surface == "" or (surface and surface.name == params.surface) then
      local asteroids = {}
      if surface then
        for _, asteroid in ipairs(surface.find_entities_filtered({type = "asteroid-chunk", limit = 1025})) do
          if #asteroids >= 1024 then V.fail("AREA_TOO_DENSE", "platform has more than 1024 observed asteroid chunks") end
          asteroids[#asteroids + 1] = {name = asteroid.name, position = position(asteroid.position),
            health = asteroid.health, max_health = asteroid.max_health}
        end
      end
      table.sort(asteroids, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        if a.position.y ~= b.position.y then return a.position.y < b.position.y end
        return a.position.x < b.position.x
      end)
      local damaged_tiles = {}
      for _, tile in ipairs(platform.damaged_tiles) do
        damaged_tiles[#damaged_tiles + 1] = {position = position(tile.position), damage = tile.damage}
      end
      table.sort(damaged_tiles, function(a, b)
        if a.position.y ~= b.position.y then return a.position.y < b.position.y end
        return a.position.x < b.position.x
      end)
      rows[#rows + 1] = {index = index, name = platform.name, force = force.name,
        surface = surface and surface.name or nil, space_location = location(platform.space_location),
        last_visited_space_location = location(platform.last_visited_space_location),
        space_connection = platform.space_connection and {name = platform.space_connection.name,
          from = platform.space_connection.from.name, to = platform.space_connection.to.name,
          length = platform.space_connection.length} or nil,
        distance = platform.distance, state = platform.state, paused = platform.paused,
        speed = platform.speed, weight = platform.weight,
        can_leave_current_location = platform.can_leave_current_location(),
        scheduled_for_deletion = platform.scheduled_for_deletion,
        hub = platform.hub and {unit_number = platform.hub.unit_number,
          position = position(platform.hub.position), health = platform.hub.health,
          inventory = platform.hub.get_inventory(defines.inventory.hub_main)
            and platform.hub.get_inventory(defines.inventory.hub_main).get_contents() or {}} or nil,
        schedule = platform.schedule, damaged_tiles = damaged_tiles, asteroid_chunks = asteroids}
    end
  end
  table.sort(rows, function(a, b) return a.index < b.index end)
  return V.page(rows, params)
end

function M.entity_detail(entity, row)
  local surface = entity.surface
  local surface_context = {name = surface.name,
    kind = surface.platform and "space-platform" or surface.planet and "planet" or "other",
    planet = surface.planet and surface.planet.name or nil,
    platform_index = surface.platform and surface.platform.index or nil,
    pollutant_type = surface.pollutant_type and surface.pollutant_type.name or nil}
  row.space_age = surface_context
  if entity.type == "asteroid-collector" then
    local filter = entity.get_filter(1)
    row.space_age.asteroid_collector = {filter = filter, output = entity.get_output_inventory()
      and entity.get_output_inventory().get_contents() or {}}
  elseif entity.type == "cargo-pod" then
    local destination = entity.cargo_pod_destination
    local station = destination and destination.station
    local platform = destination and destination.space_platform
    row.space_age.cargo_pod = {state = entity.cargo_pod_state,
      origin = entity.cargo_pod_origin and {name = entity.cargo_pod_origin.name,
        surface = entity.cargo_pod_origin.surface.name, position = position(entity.cargo_pod_origin.position)} or nil,
      destination = destination and {type = destination.type, surface = destination.surface,
        position = destination.position, transform_launch_products = destination.transform_launch_products,
        land_at_exact_position = destination.land_at_exact_position,
        station = station and {name = station.name, surface = station.surface.name,
          position = position(station.position), unit_number = station.unit_number} or nil,
        space_platform_index = platform and platform.index or nil} or nil}
  elseif entity.type == "rocket-silo" then
    row.space_age.rocket_silo = {status = entity.rocket_silo_status, rocket_parts = entity.rocket_parts,
      rocket_unit_number = entity.rocket and entity.rocket.unit_number or nil}
  elseif entity.type == "space-platform-hub" or entity.type == "cargo-landing-pad" then
    local bays = {}
    for _, bay in ipairs(entity.get_cargo_bays()) do
      bays[#bays + 1] = {name = bay.name, position = position(bay.position), unit_number = bay.unit_number}
    end
    row.space_age.cargo_bays = bays
  end
end

function M.platform(params)
  local index = V.integer(params.index, "index", 1, 4294967295)
  local result = M.platforms({force = params.force, surface = params.surface or "", offset = 0, limit = 256})
  for _, row in ipairs(result.items) do
    if row.index == index then return row end
  end
  V.fail("NOT_FOUND", "space platform does not exist for the given force and surface")
end

function M.snapshot(params)
  if not M.capabilities().available then
    return {api_version = 2, available = false, expansion = nil, planets = {items = {}, total = 0},
      space_locations = {items = {}, total = 0}, space_connections = {items = {}, total = 0},
      platforms = {items = {}, total = 0}, surfaces = {items = {}, total = 0}}
  end
  local planets, locations, connections, platforms, surfaces = {}, {}, {}, {}, {}
  local force_name = V.string(params.force, "force")
  local force = game.forces[force_name]
  if not force then V.fail("NOT_FOUND", "force does not exist: " .. force_name) end
  for _, surface in pairs(game.surfaces) do
    surfaces[#surfaces + 1] = {name = surface.name, index = surface.index,
      kind = surface.platform and "space-platform" or surface.planet and "planet" or "other",
      planet = surface.planet and surface.planet.name or nil,
      platform_index = surface.platform and surface.platform.index or nil,
      pollutant_type = surface.pollutant_type and surface.pollutant_type.name or nil,
      total_pollution = surface.get_total_pollution()}
  end
  for name, planet in pairs(game.planets) do
    local proto = planet.prototype
    planets[#planets + 1] = {name = name, surface = planet.surface and planet.surface.name or nil,
      surface_generated = planet.surface ~= nil, location = location(proto),
      pollutant_type = proto.pollutant_type and proto.pollutant_type.name or nil,
      entities_require_heating = proto.entities_require_heating,
      surface_properties = proto.surface_properties or {},
      space_platforms_unlocked = force.is_space_platforms_unlocked(),
        space_location_unlocked = force.is_space_location_unlocked(name),
      platforms = (function()
        local result = {}
      for _, platform in pairs(force.platforms) do
        if platform.space_location and platform.space_location.name == name then result[#result + 1] = platform.index end
      end
        table.sort(result)
        return result
      end)()}
  end
  for name, proto in pairs(prototypes.space_location) do locations[#locations + 1] = location(proto) end
  for name, proto in pairs(prototypes.space_connection) do
    connections[#connections + 1] = {name = name, from = proto.from.name, to = proto.to.name,
      length = proto.length}
  end
  for index, platform in pairs(force.platforms) do
    local one = M.platforms({force = force.name, offset = 0, limit = 256,
      surface = platform.surface and platform.surface.name or ""})
    for _, row in ipairs(one.items) do if row.index == index then platforms[#platforms + 1] = row end end
  end
  table.sort(surfaces, function(a, b) return a.index < b.index end)
  return {api_version = 2, available = true, expansion = "space-age",
    planets = catalog_page(planets, {offset = 0, limit = 256}),
    space_locations = catalog_page(locations, {offset = 0, limit = 256}),
    space_connections = catalog_page(connections, {offset = 0, limit = 256}),
    platforms = catalog_page(platforms, {offset = 0, limit = 256}),
    surfaces = catalog_page(surfaces, {offset = 0, limit = 256})}
end

return M
