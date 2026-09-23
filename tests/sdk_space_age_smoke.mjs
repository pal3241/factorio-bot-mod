import { pathToFileURL } from "node:url";

const entry = process.env["FBOT_SDK_ENTRY"];
const password = process.env["FBOT_RCON_PASSWORD"];
const port = Number(process.env["FBOT_RCON_PORT"]);
if (!entry || !password || !Number.isInteger(port)) throw new Error("SDK smoke environment is incomplete");

const { createBot } = await import(pathToFileURL(entry).href);
const bot = await createBot({ host: "127.0.0.1", port, password, connect_timeout_ms: 5000, request_timeout_ms: 15000 });
try {
  const capabilities = await bot.spaceAge.capabilities();
  if (!capabilities.data.available) throw new Error("Factorio SDK did not detect Space Age");
  const result = await bot.spaceAge.snapshot({ force: "player" });
  if (!result.data.available || result.apiVersion !== 2) throw new Error("Factorio SDK v2 snapshot is invalid");
  if (result.data.platforms.items.length !== 1) throw new Error("Factorio SDK did not parse the test platform");
  const platform = result.data.platforms.items[0];
  if (!platform.hub || !platform.surface) throw new Error("Factorio SDK did not parse platform hub/surface");
  const hub = await bot.world.entity({
    surface: platform.surface,
    name: "space-platform-hub",
    position: platform.hub.position,
    unit_number: platform.hub.unit_number ?? 0
  });
  if (hub.data.space_age?.kind !== "space-platform") throw new Error("Factorio SDK did not parse entity Space Age context");
  console.log(JSON.stringify({apiVersion: result.apiVersion, planets: result.data.planets.total,
    locations: result.data.space_locations.total, connections: result.data.space_connections.total,
    platforms: result.data.platforms.total, surface: platform.surface, hub: hub.data.space_age.kind}));
} finally {
  await bot.close();
}
