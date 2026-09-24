# World Sensor API

World bridge memberikan authoritative server-side observation terhadap generated world state.

## Snapshot

`snapshot` menggabungkan beberapa sensor pada satu bounded area.

```json
{
  "api_version": 1,
  "id": "world",
  "method": "snapshot",
  "params": {
    "surface": "nauvis",
    "force": "player",
    "area": {
      "left_top": {"x": -32, "y": -32},
      "right_bottom": {"x": 32, "y": 32}
    },
    "offset": 0,
    "limit": 128
  }
}
```

Mencakup:
- chunks
- entities
- resources
- electric
- logistics
- threats
- research
- bots
- players
- production
- trains

## Surfaces

`surfaces` membaca surface runtime yang tersedia, termasuk planet/platform bila Space Age menyediakan surface tersebut.

## Chunks & terrain

- `chunks` — generated/charted/visible/pollution per chunk.
- `terrain` — tile dan character-placeability.

Terrain cocok untuk pathfinder/grid planner.

## Entities

- `entities` — paginated entity summary.
- `entity` — detail entity berdasarkan stable locator tuple.

Detail dapat mencakup:
- inventories
- health/status
- energy/buffer
- fluid contents
- machine recipe/progress
- belt contents
- inserter state
- burner state
- mining target
- Space Age-specific context

## Resources

`resources` mengelompokkan resource entities menjadi observed resource patch.

Contoh resource:
- iron-ore
- copper-ore
- coal
- stone
- uranium-ore
- resource modded lainnya

Patch view memberikan posisi, bounds, tile/entity count, dan observed amount pada area query.

Query bounded berarti patch yang menyentuh batas query dapat belum lengkap. Gunakan area lebih besar/adjacent scan bila planner membutuhkan patch penuh.

## Electricity

`electric` membaca electric network context yang terlihat dalam area:
- network id
- generators
- accumulators/storage
- nominal generation context
- measured production/consumption bila runtime menyediakan statistic source

Jangan menyamakan nominal generation dengan guaranteed satisfaction.

## Logistics

`logistics` membaca logistic networks terkait area:
- robots
- roboports/context
- network contents/context sesuai runtime API

## Production

`production` membaca force production/consumption statistics untuk window yang didukung bridge.

## Research & recipes

`research`:
- current research
- progress
- queue
- researched/available technology context

`recipes`:
- force recipe availability
- ingredients/products
- enabled state

Space Age runtime content catalog memberi prototype-level data yang lebih luas.

## Trains

`trains` memberi state kereta yang relevan:
- train id
- state
- speed
- manual mode
- path availability
- carriage summary
- contents/fluids
- station/schedule context

## Threats

`threats` memberi informasi untuk defense planner:
- enemy units
- spawners
- worms/turrets
- hostile force context
- pollution sekitar scope
- evolution/peaceful context bila tersedia

World bridge **tidak memutuskan strategi combat**. Ia memberi data authoritative agar SDK/plugin/AI dapat memilih flee, attack, turret defense, wall, ammo logistics, atau pollution management.

## Players

- `players` — list player.
- `player` — detail satu player.
- `getlocation` / `player.location` — physical surface + physical position.

Physical location dipakai agar remote/map view tidak dianggap sebagai posisi tubuh player.

## Pagination & limits

Selalu baca `capabilities.limits`.

Default bridge v0.5 membatasi:
- area side
- entity scan
- page size
- event retention
- subscription count
- bot count
- request/response bytes

Desain client yang baik melakukan bounded query + cache + invalidation, bukan full-world polling setiap tick.
