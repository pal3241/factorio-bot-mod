local function request(method, params)
  local response = helpers.json_to_table(remote.call("factorio_bot_v1", "request_json",
    helpers.table_to_json({api_version = 2, id = "smoke", method = method, params = params})))
  assert(response.ok, method .. ": " .. helpers.table_to_json(response))
  return response
end

local function query()
  return {surface = "fbot-test", force = "player", area = {left_top = {x = -32, y = -32}, right_bottom = {x = 32, y = 32}}, offset = 0, limit = 256}
end

local function expect_error(method, params, expected)
  local response = helpers.json_to_table(remote.call("factorio_bot_v1", "request_json",
    helpers.table_to_json({api_version = 2, id = "negative", method = method, params = params})))
  assert(not response.ok and response.error.code == expected, "expected " .. expected .. ": " .. helpers.table_to_json(response))
end

local function spawn(name, x, y)
  local entity = game.surfaces["fbot-test"].create_entity({name = name, position = {x = x, y = y}, force = "player", raise_built = true})
  assert(entity, "fixture creation failed: " .. name)
  return entity
end

local verify_reload = false
script.on_load(function() verify_reload = storage.stage == 3 end)

script.on_init(function()
  local surface = game.create_surface("fbot-test", {width = 128, height = 128, autoplace_controls = {}, autoplace_settings = {
    entity = {treat_missing_as_default = false}, tile = {treat_missing_as_default = true}, decorative = {treat_missing_as_default = false}}})
  surface.request_to_generate_chunks({0, 0}, 2)
  surface.force_generate_chunk_requests()
  local force = game.forces.player
  force.unlock_space_platforms()
  local platform = force.create_space_platform({name = "fbot-space-test", planet = "nauvis",
    starter_pack = {name = "space-platform-starter-pack", quality = "normal"}})
  assert(platform, "Space Age test platform was not created")
  platform.apply_starter_pack(true)
  surface.clear_pollution()
  local tiles = {}
  for x = -48, 48 do for y = -48, 48 do tiles[#tiles + 1] = {name = "grass-1", position = {x, y}} end end
  surface.set_tiles(tiles)
  for _, entity in ipairs(surface.find_entities_filtered({area = {{-48, -48}, {49, 49}}})) do entity.destroy() end
  for index, name in ipairs({"iron-ore", "copper-ore", "coal", "stone", "uranium-ore"}) do
    for x = 0, 2 do surface.create_entity({name = name, position = {x + index * 5 - 20, -20}, amount = 1000}) end
  end
  spawn("small-electric-pole", 0, 0)
  spawn("solar-panel", 2, 2)
  spawn("accumulator", -2, 2)
  local machine = spawn("assembling-machine-1", -2, -2)
  machine.set_recipe("iron-gear-wheel")
  machine.insert({name = "iron-plate", count = 20})
  spawn("inserter", -4, -2)
  spawn("transport-belt", -5, -2)
  local chest = spawn("steel-chest", -6, 0)
  chest.insert({name = "iron-plate", count = 20})
  storage.chest = chest
  spawn("roboport", 10, 10)
  spawn("substation", 7, 7)
  spawn("steam-engine", 12, 1)
  local source = spawn("electric-energy-interface", 6, 3)
  source.power_production = 100000000
  source.electric_buffer_size = 100000000
  source.energy = 100000000
  for y = 14, 26, 2 do spawn("straight-rail", -20, y) end
  spawn("locomotive", -20, 20)
  surface.create_entity({name = "biter-spawner", position = {24, -24}, force = "enemy"})
  surface.create_entity({name = "small-worm-turret", position = {24, -18}, force = "enemy"})
  surface.create_entity({name = "small-biter", position = {20, -20}, force = "enemy"})
  surface.pollute({24, -24}, 100)
  game.forces.player.chart(surface, {{-32, -32}, {32, 32}})
  storage.stage = 0
end)

script.on_event(defines.events.on_tick, function()
  if verify_reload and game.tick >= 540 then
    local bot = request("bot", {id = "persisted"}).data
    assert(bot.entity.position.x > 1, "saved action did not resume")
    assert(request("shared", {network = "factory", offset = 0, limit = 10}).data.items[1].revision == 1)
    request("unwatch", {id = "persisted"})
    request("delta", {after = storage.persisted_cursor, limit = 256})
    helpers.write_file("fbot-tests/reload-result.json", helpers.table_to_json({ok = true, checks = {"bot-reference", "active-action", "shared-revision", "subscription", "event-cursor"}}), false)
    verify_reload = false
  end
  if storage.stage == 0 and game.tick >= 10 then
    storage.stage = 1
    request("capabilities", {})
    local space_caps = request("space-age.capabilities", {}).data
    assert(space_caps.available and space_caps.expansion == "space-age", "Space Age API was not detected")
    local locations = request("space-age.locations", {offset = 0, limit = 256}).data
    local planets = request("space-age.planets", {offset = 0, limit = 256}).data
    local connections = request("space-age.connections", {offset = 0, limit = 256}).data
    assert(planets.total >= 5 and locations.total >= planets.total and connections.total > 0, "Space Age catalog is incomplete")
    local platforms = request("space-age.platforms", {force = "player", offset = 0, limit = 256}).data
    assert(platforms.total == 1 and platforms.items[1].name == "fbot-space-test", "space platform query failed")
    local platform_detail = request("space-age.platform", {force = "player", index = platforms.items[1].index}).data
    assert(platform_detail.index == platforms.items[1].index and platform_detail.hub, "space platform detail or hub missing")
    local hub = request("entity", {surface = platform_detail.surface, name = "space-platform-hub",
      position = platform_detail.hub.position, unit_number = platform_detail.hub.unit_number}).data
    assert(hub.space_age.kind == "space-platform" and hub.space_age.cargo_bays,
      "space platform hub context is missing")
    local space_snapshot = request("space-age.snapshot", {force = "player"}).data
    assert(space_snapshot.available and space_snapshot.platforms.total == 1 and space_snapshot.surfaces.total > 1,
      "Space Age cross-surface snapshot failed")
    local cursor, space_event = 0, false
    for _ = 1, 16 do
      local delta = request("delta", {after = cursor, limit = 256}).data
      for _, event in ipairs(delta.items) do if event.kind == "space-age.invalidated" then space_event = true end end
      cursor = delta.next_cursor
      if not delta.has_more then break end
    end
    assert(space_event, "Space Age platform events did not invalidate world state")
    helpers.write_file("fbot-tests/space-age.json", helpers.table_to_json({capabilities = space_caps,
      planets = planets, locations = locations, connections = connections, platforms = platforms,
      snapshot = space_snapshot}), false)
    for _, method in ipairs({"surfaces", "chunks", "terrain", "entities", "research", "recipes", "production", "electric", "logistics", "trains", "threats", "bots", "players", "snapshot"}) do
      local result = request(method, query())
      helpers.write_file("fbot-tests/" .. method .. ".json", helpers.table_to_json(result), false)
    end
    local patches = request("resources", query()).data
    assert(patches.total == 5, "expected five separate resource patches")
    for _, patch in ipairs(patches.items) do assert(patch.observed_amount == 3000 and patch.tile_count == 3) end
    local electric = request("electric", query()).data.items
    assert(electric[1].observed_storage_capacity_j == 5000000 and electric[1].observed_nominal_generation_w == 60000)
    assert(electric[1].measured.production_w > 0 and electric[1].satisfaction.available == false)
    local generator_found = false
    for _, network in ipairs(electric) do
      for _, generator in ipairs(network.generators) do
        if generator.name == "steam-engine" then
          assert(generator.nominal_w == 900000, "incorrect steam-engine nominal capacity: " .. generator.nominal_w)
          generator_found = true
        end
      end
    end
    assert(generator_found, "steam-engine missing from observed electric network")
    assert(request("logistics", query()).data.total == 1)
    assert(request("trains", query()).data.total == 1)
    local threats = {}
    for _, threat in ipairs(request("threats", query()).data.items) do threats[threat.type] = true end
    assert(threats["unit-spawner"] and threats.turret and threats.unit)
    local entities = request("entities", query()).data.items
    for _, entity in ipairs(entities) do
      request("entity", {surface = entity.surface, position = entity.position, name = entity.name, unit_number = entity.unit_number or 0})
    end
    local bad = helpers.json_to_table(remote.call("factorio_bot_v1", "request_json", '{"api_version":99,"id":"bad","method":"capabilities","params":{}}'))
    assert(not bad.ok and bad.error.code == "VERSION_MISMATCH")
    bad = helpers.json_to_table(remote.call("factorio_bot_v1", "request_json", '{'))
    assert(not bad.ok and bad.error.code == "INVALID_JSON")
    request("bot.create", {id = "worker", network = "factory", surface = "fbot-test", force = "player", position = {x = 0, y = -10}})
    local ghost = request("bot.build-ghost", {id = "worker", name = "stone-furnace", position = {x = 4, y = -14}, direction = 0}).data
    assert(ghost.name == "stone-furnace" and ghost.construction_registered and #ghost.required_items > 0,
      "machine ghost was not registered with its construction requirements")
    local ghost_entity = request("entity", {surface = ghost.surface, name = "entity-ghost", position = ghost.position, unit_number = ghost.ghost_unit_number}).data
    assert(ghost_entity.ghost.ghost_name == "stone-furnace" and ghost_entity.ghost.construction_registered,
      "ghost entity detail did not expose its construction state")
    expect_error("bot.build-ghost", {id = "worker", name = "stone-furnace", position = {x = 4, y = -14}, direction = 0}, "CONFLICT")
    local bot = request("bot", {id = "worker"}).data
    storage.bot_unit = bot.entity.unit_number
    local character = game.surfaces["fbot-test"].find_entities_filtered({type = "character"})[1]
    storage.character = character
    character.destructible = false
    character.insert({name = "iron-plate", count = 10})
    assert(request("craftable", {id = "worker", recipe = "iron-gear-wheel"}).data.count > 0)
    request("bot.craft", {id = "worker", recipe = "iron-gear-wheel", count = 1})
    request("bot.walk", {id = "worker", direction = 4, ticks = 30})
    request("shared.write", {network = "factory", key = "job", value = "mine", expected_revision = 0})
    expect_error("shared.write", {network = "factory", key = "job", value = "other", expected_revision = 0}, "CONFLICT")
    expect_error("bot.walk", {id = "worker", direction = 3, ticks = 30}, "INVALID_ARGUMENT")
    expect_error("bot.destroy", {id = "worker"}, "BOT_NOT_EMPTY")
    expect_error("bot.create", {id = "worker", network = "factory", surface = "fbot-test", force = "player", position = {x = 0, y = 0}}, "CONFLICT")
    expect_error("entities", {surface = "fbot-test", force = "player", area = {left_top = {x = 0, y = 0}, right_bottom = {x = 129, y = 10}}, offset = 0, limit = 1}, "INVALID_ARGUMENT")
    local first = query()
    first.limit = 2
    local page = request("entities", first).data
    assert(#page.items == 2 and page.next_offset == 2)
    first.offset = page.next_offset
    local next_page = request("entities", first).data
    assert(#next_page.items == 2 and next_page.next_offset == 4)
    assert(request("shared", {network = "factory", offset = 0, limit = 10}).data.items[1].revision == 1)
    request("watch", {id = "entities", topic = "entities", interval = 120, query = query()})
    request("watch", {id = "inventory", topic = "entity", interval = 120, query = {
      surface = "fbot-test", position = storage.chest.position, name = storage.chest.name,
      unit_number = storage.chest.unit_number, offset = 0, limit = 256}})
    storage.cursor = request("delta", {after = 0, limit = 256}).cursor
    storage.chest.damage(10, "enemy", "physical")
    storage.chest.insert({name = "copper-plate", count = 5})
    local research_cursor = request("capabilities", {}).cursor
    game.forces.player.technologies.automation.researched = true
    local changes = request("delta", {after = research_cursor, limit = 256}).data.items
    local research_event = false
    for _, event in ipairs(changes) do if event.kind == "research.changed" then research_event = true end end
    assert(research_event, "research completion did not invalidate research state")
  elseif storage.stage == 1 and game.tick >= 200 then
    storage.stage = 2
    local bot = request("bot", {id = "worker"}).data
    assert(bot.entity.position.x > 1, "virtual character did not walk")
    local character = storage.character
    assert(character.get_item_count("iron-gear-wheel") == 1, "virtual character did not craft")
    local delta = request("delta", {after = storage.cursor, limit = 256}).data
    local changed, inventory_changed = false, false
    for _, event in ipairs(delta.items) do
      if event.kind == "watch.changed" and event.data.id == "entities" then changed = true end
      if event.kind == "watch.changed" and event.data.id == "inventory" then inventory_changed = true end
    end
    assert(changed and inventory_changed, "subscriptions did not report changed world/inventory state")
    request("unwatch", {id = "entities"})
    request("unwatch", {id = "inventory"})
    character.teleport({0, -18}, game.surfaces["fbot-test"])
    request("bot.mine", {id = "worker", position = {x = 0, y = -20}, ticks = 240})
  elseif storage.stage == 2 and game.tick >= 500 then
    storage.stage = 3
    local character = storage.character
    assert(character.get_item_count("stone") > 0, "virtual character did not mine: " .. helpers.table_to_json({inventory = character.get_main_inventory().get_contents(), progress = character.character_mining_progress, state = character.mining_state, selected = character.selected and character.selected.name}))
    request("bot.stop", {id = "worker"})
    character.clear_items_inside()
    request("bot.destroy", {id = "worker"})
    assert(request("bots", {offset = 0, limit = 256}).data.total == 0)
    local before_expiry = request("capabilities", {}).cursor
    for index = 1, 2050 do
      storage.chest.health = storage.chest.max_health
      storage.chest.damage(1, "enemy", "physical")
    end
    expect_error("delta", {after = before_expiry, limit = 256}, "CURSOR_EXPIRED")
    request("bot.create", {id = "persisted", network = "factory", surface = "fbot-test", force = "player", position = {x = 0, y = -10}})
    request("bot.walk", {id = "persisted", direction = 4, ticks = 100})
    request("watch", {id = "persisted", topic = "bots", interval = 120, query = {offset = 0, limit = 256}})
    storage.persisted_cursor = request("capabilities", {}).cursor
    local result = {ok = true, tick = game.tick, engine = script.active_mods.base,
      tests = {"all-sensors", "snapshot-json", "entity-details", "five-resource-patches", "electric-nominal-and-storage", "invalid-json-version-area-direction", "virtual-character-walk-craft-mine", "machine-ghost-construction-registration", "shared-state-cas", "pagination", "event-cursor-expiry", "research-event", "entity-and-inventory-subscriptions", "space-age-catalog-platform-hub-cross-surface-events"}}
    helpers.write_file("fbot-tests/result.json", helpers.table_to_json(result), false)
    log("FBOT_INTEGRATION_PASS " .. helpers.table_to_json(result))
    game.server_save("fbot-tested")
  end
end)
