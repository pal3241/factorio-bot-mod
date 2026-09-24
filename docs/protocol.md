# Protocol/API v1 and v2

## Transport dan envelope

Command `/fbot <JSON>` mengembalikan satu dokumen JSON. Client RCON harus menggabungkan frame respons sebelum parsing. Dari mod lain:

```lua
local response_json = remote.call("factorio_bot_v1", "request_json",
  helpers.table_to_json({api_version = 1, id = "q1", method = "capabilities", params = {}}))
local response = helpers.json_to_table(response_json)
```

API lama memakai `api_version: 1`; endpoint Space Age memakai `api_version: 2`. Envelope response mengulang versi request. `id: string`, `method: string`, `params: object` tetap wajib. ID dan string parameter maksimum 128 byte; JSON request maksimum 8192 byte. ID hanya untuk korelasi, **bukan idempotency key**. Jangan mengulang mutation setelah timeout tanpa merekonsiliasi state. Field tambahan yang tidak digunakan diabaikan. Parameter wajib tidak mempunyai default tersembunyi.

Respons normal:

```json
{"api_version":1,"id":"q1","tick":120,"cursor":34,"ok":true,"data":{}}
```

Respons gagal:

```json
{"api_version":1,"id":"q1","tick":120,"cursor":34,"ok":false,"error":{"code":"NOT_FOUND","message":"surface does not exist: missing"}}
```

Kesalahan sebelum request terurai atau saat serialisasi dapat tidak mempunyai `id`, `tick`, atau `cursor`. Field `nil` di Lua dihilangkan. **Factorio mengodekan array kosong sebagai `{}`**; SDK harus menerima `{}` sebagai koleksi kosong hanya pada field yang didokumentasikan sebagai array. Angka memakai representasi JSON Factorio. `unit_number`, indeks surface, dan network ID hanya berlaku dalam save berjalan; network dapat berubah setelah pembangunan, pemutusan kabel, atau merge.

Query maksimum 32 request/tick secara default (`fbot-query-budget`, rentang 1–128). Request yang ditolak juga dapat memakai budget. Jika game paused dan budget habis, majukan tick sebelum retry. Respons maksimum 1 MiB; respons terlalu besar menghasilkan `RESPONSE_TOO_LARGE`. Tidak ada request Lua mentah atau evaluasi kode pada protocol ini.

## Parameter bersama

`Page`: `offset` integer ≥ 0, `limit` integer 1–256. Hasil `{items: array, total: integer, next_offset?: integer}`. Tidak adanya `next_offset` berarti selesai.

`AreaPage`: seluruh `Page`, ditambah `surface` nama surface, `force` nama force, `area: {left_top:{x,y}, right_bottom:{x,y}}`. Lebar dan tinggi positif, masing-masing ≤128 tile. Koordinat finite dalam ±1.000.000. Sudut kanan bawah eksklusif untuk grid tile/chunk; entity mengikuti aturan overlap bounding box engine. Scan entity dibatasi 16.384; area terlalu padat ditolak dan harus diperkecil.

Pagination adalah pembacaan live, bukan transaksi lintas request. Objek bergerak, riset berubah, dan entity baru bisa menggeser halaman. Gunakan tick/cursor, query area kecil, dan reconcile ulang setelah invalidation. Snapshot mengembalikan halaman pertama/offset yang sama untuk setiap koleksi, **bukan seluruh dunia atau semua halaman**.

## Queries

| Method | Parameter wajib | Data/semantik |
| --- | --- | --- |
| `capabilities` | object kosong | Versi, method, limit, status action, model observasi |
| `snapshot` | AreaPage | Chunks, entities, resources, electric, logistics, threats, research, bots, players, production, trains; satu tick yang sama |
| `surfaces` | Page | Nama/index, daytime/darkness, peaceful mode, multiplier solar, pollutant |
| `chunks` | AreaPage | Generated/charted/visible, posisi chunk, pollution sampled per chunk |
| `entities` | AreaPage | Ringkasan semua entity dalam area, termasuk force lain/neutral |
| `entity` | `surface`, `name`, `position:{x,y}`, `unit_number` | Detail entity dengan locator exact posisi tengah; `unit_number:0` untuk entity tanpa unit number |
| `terrain` | AreaPage | Tile row-major, collision mask, generated, character placement check di pusat tile |
| `resources` | AreaPage | Patch iron-ore, copper-ore, coal, stone, uranium-ore |
| `electric` | AreaPage | Jaringan force yang intersect area, flow terukur dan anggota yang teramati |
| `logistics` | AreaPage | Jaringan yang memiliki roboport force dalam area, item quality counts, robot/cell/charging context |
| `trains` | AreaPage | Kereta force dengan carriage dalam area; ID, state, speed, schedule, station, cargo/fluid |
| `production` | AreaPage | Counter produksi/consumption item dan fluid **force+surface**, total dan average satu menit; area hanya validasi konteks |
| `research` | `force`, Page | Semua teknologi, completed/enabled/available, prerequisites, ingredients, unit count, saved/current progress, trigger, queue |
| `recipes` | `force`, Page | Recipe enabled/category/ingredients/products/time/surface conditions |
| `threats` | AreaPage | Semua hostile entity di area, health/range/resistance/attack prototype, evolution per hostile force/surface, pollution context |
| `players` | Page | Player nyata, connected/controller, force/surface/position/character |
| `bots` | Page | Registry seluruh bot, network label, alive, action, entity summary |
| `bot` | `id` | Detail karakter virtual, inventories, crafting queue/progress, action |
| `craftable` | `id`, `recipe` | Enabled dan jumlah hand-craftable menurut engine untuk bot tersebut |
| `shared` | `network`, Page | Key/value string, revision, tick untuk kelompok bot |
| `delta` | `after` integer ≥0, `limit` 1–256 | Event setelah sequence, next/head cursor, has_more |

`force` adalah konteks riset, diplomacy, dan network; bukan filter global untuk `entities`, `resources`, `terrain`, atau daftar bot/player. Registry/shared network adalah label koordinasi logis, terpisah dari electric/logistic networks Factorio. State shared maksimum 256 key; tidak menjalankan job atau planner.

Entity summary: `unit_number?`, `name`, `type`, `position`, `surface`, `force`, `direction`, `quality`, `health?`, `max_health?`, `status?`, `bounding_box`. Detail menambahkan `inventories:[{index,slots,contents:[{name,quality,count}]}]`, fluid contents, energy/buffer, electric network ID, collision mask, dan context bertipe: machine recipe/progress/speed/products, drill target, belt line contents/speed, inserter held stack/positions, burner fuel. Indeks inventory/status/direction mengikuti `defines` Factorio 2.0. Entity bergerak harus ditemukan ulang sebelum memakai locator. Locator juga mencakup entity tanpa unit number, misalnya resource.

### Resource patches

Flood-fill deterministik 8-neighbour pada tile dengan resource bernama sama. Setiap patch berisi posisi rata-rata, bounds, tile_count, observed_amount, estimated_amount, dan `touches_query_boundary`. Amount adalah penjumlahan resource entity yang teramati; **tidak menebak bagian patch di luar area**. Estimated amount sama dengan observed amount pada v1. `query_local_id` bukan ID global yang stabil: patch bisa split/merge, bergeser seed setelah mining, atau terpotong area. SDK perlu menyatukan observasi area bersebelahan jika menginginkan peta patch global. Layout modded dengan dua resource sejenis pada satu tile ditolak secara eksplisit.

### Listrik

`measured` berasal dari statistik electric pole yang ditemukan, mencakup **seluruh network**, rata-rata lima detik. Engine memberi joule/tick; API mengalikan 60 untuk watt. Production/consumption mencakup charging/discharging accumulator sebagaimana statistik engine. Tidak adanya pole dalam area menyebabkan `measured` tidak tersedia.

`observed_nominal_generation_w`, `observed_storage_j`, `observed_storage_capacity_j`, generators, dan accumulators mencakup **anggota dalam area saja**. Nominal generation adalah maksimum teoritis berdasarkan prototype/quality, bukan daya yang pasti tersedia: malam, bahan bakar, steam temperature/flow, sambungan, serta modifier permukaan berpengaruh. Gunakan status dan context generator serta data surface. Jangan menjumlahkan repeated whole-network flow dari area yang overlap.

`satisfaction = {available:false, reason:...}` eksplisit: API 2.0 tidak menyediakan total unmet demand jaringan secara langsung. Rasio consumption/production bukan satisfaction karena keduanya dapat sama saat kekurangan daya. Jangan menampilkan angka satisfaction palsu. Storage adalah energi buffer accumulator teramati, bukan semua buffer mesin.

### Riset, threats, dan navigasi

`available` berarti teknologi enabled, belum researched, research force enabled, dan prerequisites researched. Itu **bukan** jaminan science tersedia atau trigger terpenuhi. Infinite research diwakili level/current state dari engine. Recipe `enabled` juga bukan bukti bot bisa craft; pakai `craftable` untuk karakter tertentu.

Threats memakai `force.is_enemy`, sehingga diplomacy dan ceasefire mengikuti engine. Rentang/cooldown/damage dari prototype adalah masukan untuk SDK, bukan prediksi serangan. Posisi nest/worm/unit, evolusi, pollution per posisi/chunk, health/status entity sendiri, inventory ammo, recipe dan teknologi memberi dasar untuk keputusan defensif di SDK. Data ini tidak menjanjikan semua pergerakan musuh akan menghasilkan event native; gunakan subscription di perimeter yang relevan.

Terrain `character_placeable` adalah collision check native di pusat tile pada saat query. Ini bukan pathfinding, analisis arah belt, atau jaminan rute terus terbuka. Query tidak membuat chunk baru, menghapus fog, atau mengeksplorasi dunia secara otomatis.

## Space Age API v2

Method berikut read-only dan mengembalikan `available:false` jika Space Age tidak aktif pada save. Query tidak membuat planet, surface, atau platform. Daftar menggunakan pagination v1.

| Method | Parameter wajib | Data/semantik |
| --- | --- | --- |
| `space-age.capabilities` | object kosong | Status DLC dan fitur yang terpasang |
| `space-age.planets` | Page | Planet, surface jika sudah dibuat, polusi/heating rules, surface properties, jumlah platform |
| `space-age.locations` | Page | Space-location prototype, termasuk posisi starmap, jarak, gravitasi, asteroid spawn influence dan properties |
| `space-age.connections` | Page | Rute antar lokasi dan panjang koneksi |
| `space-age.platforms` | `force`, Page, `surface?` | Platform per force: lokasi/koneksi/transit, status, speed/weight, hub dan inventory, jadwal, tile rusak, asteroid teramati |
| `space-age.platform` | `force`, `index`, `surface?` | Satu platform |
| `space-age.snapshot` | `force` | Katalog Space Age dan semua surface save yang ada; bukan transaksi lintas request |

`world.surfaces` mencakup surface planet dan platform. Detail `world.entity` menambahkan context surface Space Age, cargo-pod state/origin/destination, rocket-silo state, cargo bays hub/landing pad, serta filter/output asteroid collector. ID entity, recipe, asteroid, item, lokasi, koneksi, dan property mengikuti Factorio; SDK tidak hardcode daftar planet vanilla. Dukungan adapter untuk mod pihak ketiga adalah milestone v0.3.

Asteroid chunks adalah observasi yang ada di surface platform saat query, bukan prediksi spawn. Masing-masing platform dibatasi 1024 chunk; data lebih besar ditolak eksplisit. Platform tanpa surface tetap muncul tanpa entity/tile context. Field koneksi mengikuti API 2.0.77 (tidak mengandalkan `shape` yang baru tersedia pada API 2.1).

Event `space-age.invalidated` menandai perubahan platform, pembangunan/mining platform, cargo pod, dan peluncuran roket. Payload memberi surface/unit/platform index bila tersedia; SDK harus membaca ulang query terkait. Watch mendukung `space-age.platforms` dan `space-age.planets`.

## Actions

Semua mutation di bawah memerlukan setting `fbot-enable-actions=true`. Administrator dapat mengubahnya melalui UI atau command `/fbot-enable-actions` dan `/fbot-disable-actions`. Dua command administrasi ini tidak tersedia pada remote JSON interface. Action mengganti state engine melalui adapter; tidak ada AI.

| Method | Parameter wajib | Hasil |
| --- | --- | --- |
| `bot.create` | `id`, `network`, `surface`, `force`, `position` | Membuat karakter normal tanpa item; maksimum 32 bot |
| `bot.destroy` | `id` | Menghapus karakter kosong/registry bot mati; inventory atau crafting aktif menyebabkan `BOT_NOT_EMPTY` |
| `bot.walk` | `id`, `direction`, `ticks` | Direction delapan arah 0,2,4,6,8,10,12,14; north=0, east=4; durasi 1–600 tick |
| `bot.stop` | `id` | Menghentikan walk/mining; tidak membatalkan crafting queue |
| `bot.mine` | `id`, `position`, `ticks` | Mining native bertempo selama 1–600 tick terhadap target terpilih yang reachable |
| `bot.craft` | `id`, `recipe`, `count` 1–100 | Memulai hand crafting native menggunakan inventory; hasil `started` adalah jumlah yang diterima engine |
| `bot.build-ghost` | `id`, `name`, `position`, `direction` | Membuat machine ghost Factorio setelah memeriksa prototype placeable, generated chunk, jangkauan bot, duplikasi, dan collision. Hasil mencakup `ghost_unit_number`, `construction_registered`, serta `required_items` untuk jaringan construction.
| `shared.write` | `network`, `key`, `value`, `expected_revision` | Compare-and-set string; revision awal 0, naik satu setiap penulisan |

Walk/mining adalah command durasi terbatas yang dijalankan ulang setiap tick, bukan teleport atau instant mining. Berjalan dapat terhalang dan mining dapat berhenti ketika target hilang. Satu bot mempunyai satu action walk/mining aktif; perintah berikut menggantikannya. Durasi bukan jaminan pekerjaan selesai: SDK perlu membaca posisi/inventory dan delta. Bot baru tidak diberi invulnerability atau item gratis. Bot mati tetap tercatat `alive:false`; hapus registrynya sebelum menggunakan ID yang sama. Destruction menolak inventory/crafting supaya item tidak hilang diam-diam.

## Event log dan subscription

Sequence monoton, event ring 2048 entry, tersimpan di save. `delta` mengembalikan `{items:[{sequence,tick,kind,data}],next_cursor,head_cursor,has_more}`. Cursor yang lebih tua daripada retention menyebabkan `CURSOR_EXPIRED`: ambil snapshot ulang. Cursor lebih besar dari head juga ditolak, misalnya setelah restore save lama. Konsumen menyimpan cursor setelah berhasil memproses halaman. Cursor envelope menunjukkan head saat request; untuk drain event selalu lanjutkan dari **data.next_cursor**, bukan head.

Event native mencakup pembangunan/mining/destruction/death/resource depletion/rotation/damage, chunk generated/deleted, tile changes, player lifecycle/inventory, riset lifecycle, surface/force changes, train state, dan perubahan setting. Payload entity adalah state pada callback, bukan bukti entity masih hidup. `world.invalidated` memerlukan refresh scope terkait. Mod lain yang memutasi dunia tanpa raise event tidak otomatis terlihat di log native.

```text
/fbot {"api_version":1,"id":"watch-q","method":"watch","params":{"id":"perimeter","topic":"threats","interval":120,"query":{"surface":"nauvis","force":"player","area":{"left_top":{"x":-32,"y":-32},"right_bottom":{"x":32,"y":32}},"offset":0,"limit":256}}}
/fbot {"api_version":1,"id":"poll-q","method":"delta","params":{"after":0,"limit":128}}
/fbot {"api_version":1,"id":"unwatch-q","method":"unwatch","params":{"id":"perimeter"}}
```

`watch`: `id`, `topic`, `interval` 120–3600 tick, `query` dengan seluruh parameter topic serta **offset=0, limit=256** (juga untuk single-object topic). Topic: entities, entity, bot, chunks, resources, electric, logistics, threats, research, bots, production, trains. Maksimum 8 watch. Respons berisi state `initial`; catat cursor respons sebagai baseline. Memakai ID yang sama mengganti subscription.

Sampling berjalan pada kelipatan 60 tick, sehingga pengamatan pertama setelah interval dapat terlambat hingga 59 tick. `watch.changed` berisi id/topic untuk dibaca ulang, bukan diff setiap field. Untuk inventory/belt/machine gunakan topic `entity`; untuk inventory bot gunakan `bot`. Topic `entities` hanya membandingkan summary. Pollution menggunakan topic `chunks`/`threats`. Research/production yang melebihi satu page tidak bisa di-watch; gunakan event native + paginated targeted query.

Jika scope tumbuh melebihi satu page/128 KiB atau query gagal (misalnya entity dihancurkan), subscription dihentikan dengan `watch.error` dan alasan spesifik. Tidak ada silent retry. Bot action dan event native diproses setiap tick; sensor area hanya sesuai query/subscription. Ini adalah event-driven invalidation dengan sampling, **bukan changelog lengkap setiap inventory transfer atau setiap tick**.

## Error dan kompatibilitas

Kode utama: INVALID_REQUEST, INVALID_JSON, INVALID_ARGUMENT, VERSION_MISMATCH, UNKNOWN_METHOD, FORBIDDEN, NOT_FOUND, RATE_LIMIT, AREA_TOO_DENSE, RESPONSE_TOO_LARGE, CURSOR_EXPIRED, WATCH_TOO_LARGE, NETWORK_TOO_LARGE, ACTIONS_DISABLED, CONFLICT, LIMIT, BOT_DEAD, BOT_NOT_EMPTY, COLLISION, UNGENERATED_CHUNK, UNREACHABLE_TARGET, NOT_CRAFTABLE, CRAFT_FAILED, CREATE_FAILED, DESTROY_FAILED, UNSUPPORTED_RESOURCE_LAYOUT, STORAGE_VERSION, NOT_INITIALIZED, ENGINE_ERROR.

Engine error ditampilkan dengan pesan asli; SDK tidak boleh menutupinya dengan data kosong. Retriable rate-limit ditangani client setelah tick maju; input, version, collision, atau conflict harus diselesaikan dahulu. Mutation timeout harus direkonsiliasi, bukan blind retry. Schema storage v1 dipertahankan saat reload/configuration change; schema lain ditolak eksplisit. Penambahan field v1 boleh diabaikan client; breaking contract memerlukan remote interface/version baru.

Cakupan v0.2 diuji di Factorio 2.0.77 dengan Space Age, Quality, dan Elevated Rails aktif. Entity segmented unit terbaca lewat sensor generik LuaEntity; adapter khusus mod pihak ketiga adalah milestone v0.3. API ini menambah v2 tanpa menghapus method v1.


## Chat and player location (v0.4)

### `player`

Looks up one player by `name` or `player_index` and returns the same structured player view used by `players`.

```json
{"api_version":1,"id":"p1","method":"player","params":{"name":"Fahri"}}
```

### `getlocation` / `player.location`

Aliases that return the player's current physical location:

```json
{
  "player_index": 1,
  "name": "Fahri",
  "connected": true,
  "force": "player",
  "surface": "nauvis",
  "position": {"x": 12.5, "y": -8.25}
}
```

The physical position/surface are used so a remote/map controller view does not move the reported body location.

### `chat.message` event

Plain in-game chat is appended to the normal ordered delta event log:

```json
{
  "sequence": 42,
  "tick": 12345,
  "kind": "chat.message",
  "data": {
    "source": "player",
    "message": "Sena sini",
    "player_index": 1,
    "player_name": "Fahri",
    "connected": true,
    "force": "player",
    "surface": "nauvis",
    "position": {"x": 12.5, "y": -8.25}
  }
}
```

Server-interface messages use `source: "server"` and have no player position. Factorio slash commands are not emitted as `chat.message`.

### `chat.send`

Mutation for bot/API responses:

```json
{"api_version":1,"id":"say1","method":"chat.send","params":{"sender":"Sena","message":"Aku datang.","force":"player"}}
```

The optional `force` limits visibility to that force. Because this is a mutation, `fbot-enable-actions` must be enabled.
