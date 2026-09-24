# Factorio Bot World Bridge v0.4.0

Mod Lua native untuk sensor dunia dan karakter virtual server-side. Target: Factorio **2.0.77+ pada seri 2.0**, termasuk data Space Age. Tidak memerlukan Node.js, layanan web, AI, atau library Lua eksternal di runtime. Sensor biasa memakai protocol v1; Space Age memakai v2. Dependency Space Age bersifat opsional.

## Instalasi

1. Salin isi repo ke folder `factorio-bot-mod_0.4.0` dalam direktori `mods` Factorio, atau pasang ZIP rilis. Pada instalasi Windows standar: `%APPDATA%\Factorio\mods`.
2. Aktifkan **Factorio Bot World Bridge** dan muat save. Server dan client multiplayer perlu mod yang sama.
3. Jalankan command ini dari console admin; dari RCON gunakan command yang sama:

```text
/fbot {"api_version":1,"id":"hello","method":"capabilities","params":{}}
```

Mod tidak membuka socket sendiri. **Headless server tidak wajib.** Untuk bermain pada instance Factorio desktop yang sama, host world sebagai multiplayer dari GUI lalu aktifkan konfigurasi `local-rcon-socket` dan `local-rcon-password` di Factorio. SDK v0.4 dapat terhubung langsung ke local RCON socket tersebut sehingga hanya ada satu instance Factorio dengan grafik.

Dedicated/headless tetap didukung bila dibutuhkan:

```text
factorio --start-server factory.zip --rcon-bind 127.0.0.1:27015 --rcon-password REPLACE_WITH_YOUR_PASSWORD
```

Factorio sendiri tidak menyediakan RCON untuk true single-player; direct mode berarti GUI-hosted multiplayer pada instance desktop yang sedang dimainkan.

Untuk koneksi jarak jauh, gunakan jaringan privat/tunnel. RCON memberi akses administrator server; protocol ini bukan batas keamanan bagi pemilik kredensial RCON. Query bersifat **server-omniscient**, termasuk area generated yang belum di-chart. Command hanya tersedia untuk admin dan console server; remote interface ditujukan untuk mod tepercaya dalam save yang sama.

## Membaca dunia

```text
/fbot {"api_version":1,"id":"world-1","method":"snapshot","params":{"surface":"nauvis","force":"player","area":{"left_top":{"x":-32,"y":-32},"right_bottom":{"x":32,"y":32}},"offset":0,"limit":128}}
```

Snapshot mencakup area terbatas. Gunakan `surfaces`, `chunks`, `entities`, `entity`, `resources`, `terrain`, `electric`, `logistics`, `production`, `trains`, `research`, `recipes`, `threats`, `players`, `player`, `getlocation`, dan `bots` untuk query terarah. Lihat [protocol/API](docs/protocol.md) untuk semua parameter, satuan, pagination, dan arti ketidaklengkapan data.


## Chat dan lokasi player

Mod menangkap pesan chat biasa melalui event Factorio dan menulisnya sebagai event `chat.message` pada ordered event log. Payload player menyertakan `player_index`, `player_name`, force, surface, dan **physical position** saat pesan diterima. Pesan dari server interface tetap dicatat dengan `source = "server"` tetapi tidak mempunyai posisi player.

```text
/fbot {"api_version":1,"id":"where","method":"getlocation","params":{"name":"Fahri"}}
/fbot {"api_version":1,"id":"where2","method":"player.location","params":{"player_index":1}}
```

Lookup `player` mengembalikan state player lengkap yang setara dengan item dari query `players`. `getlocation` dan `player.location` adalah alias yang mengembalikan payload lokasi ringkas.

Jika actions diaktifkan, bridge juga bisa menulis pesan ke chat:

```text
/fbot {"api_version":1,"id":"say","method":"chat.send","params":{"sender":"Sena","message":"Aku datang.","force":"player"}}
```

`on_console_chat` hanya dipakai untuk pesan chat biasa. Slash-command Factorio bukan `chat.message` dan sengaja tidak diperlakukan sebagai command bot oleh bridge.

## Space Age

Query DLC mencakup planet, space locations/koneksi, platform, jadwal/transit, hub dan inventori, asteroid chunks teramati, context cargo pod/rocket/hub/asteroid collector pada detail entity, semua surface yang tersedia, dan invalidation events. v0.3 juga menambahkan runtime content catalog untuk item, fluid, entity, recipe, technology, quality, tile, space location, dan space connection, termasuk konten Space Age/modded yang aktif pada save. Query hanya membaca data dan tidak membuat surface, planet, atau platform. Pada game tanpa DLC, capability menjelaskan bahwa Space Age tidak aktif.

```text
/fbot {"api_version":2,"id":"space","method":"space-age.snapshot","params":{"force":"player"}}
/fbot {"api_version":2,"id":"platforms","method":"space-age.platforms","params":{"force":"player","offset":0,"limit":128}}
/fbot {"api_version":2,"id":"catalog","method":"space-age.content","params":{"category":"technologies","offset":0,"limit":128}}
```

Validasi v0.2 dijalankan dengan Factorio 2.0.77 dan DLC Space Age aktif. Adapter mod pihak ketiga merupakan milestone v0.3.

## Bot virtual

Aktifkan **Settings → Mod settings → Map → fbot-enable-actions**, atau command admin/RCON `/fbot-enable-actions`. Untuk menonaktifkan gunakan `/fbot-disable-actions`. Default rilis adalah `false` agar pemasangan mod hanya mengaktifkan sensor. Setting ini juga mengendalikan penulisan shared state. Menonaktifkannya menghentikan walk/mining aktif pada tick berikutnya; crafting yang sudah diterima engine tetap berjalan.

```text
/fbot {"api_version":1,"id":"create-1","method":"bot.create","params":{"id":"worker-1","network":"factory-a","surface":"nauvis","force":"player","position":{"x":0,"y":0}}}
/fbot {"api_version":1,"id":"walk-1","method":"bot.walk","params":{"id":"worker-1","direction":4,"ticks":60}}
/fbot {"api_version":1,"id":"state-1","method":"bot","params":{"id":"worker-1"}}
/fbot {"api_version":1,"id":"stop-1","method":"bot.stop","params":{"id":"worker-1"}}
```

Lokasi spawn harus sudah generated dan bebas collision. Bot adalah `LuaEntity` bertipe `character`, bukan akun Steam, koneksi LAN palsu, atau `LuaPlayer`. Bot memiliki inventory, health, collision, hand crafting, dan mining native; kematian mengikuti engine. Primitive action mencakup create, destroy, bounded walk, stop, timed mining, hand crafting, dan `bot.build-ghost`. Ghost mengikuti force bot dan meminta item mesin yang dibutuhkan; construction robots Factorio membangunnya jika jaringan memiliki robot dan material. Hive tidak memindahkan item atau mengendalikan robot secara langsung.

## Event dan subscription

Ambil `cursor` dari snapshot, lalu panggil `delta` dengan `after` cursor tersebut. Event memberitahukan perubahan/invalidation; baca ulang objek atau area terkait. Gunakan `watch` untuk perubahan kontinu seperti listrik, resource amount, inventory, atau research progress yang tidak selalu mempunyai event native. Tidak ada pemindaian seluruh dunia pada setiap tick.

## Validasi nyata

Python 3.11+ hanya diperlukan untuk pengujian. Runner menggunakan executable Factorio milik pengguna dan standard library Python, membuat direktori sementara serta save tersendiri, menjalankan server lokal + RCON, lalu memuat ulang save. Tidak mengubah folder mods, konfigurasi, atau save permainan pengguna.

```powershell
python tests/run_integration.py --factorio "D:/SteamLibrary/steamapps/common/Factorio/bin/x64/factorio.exe" --data "D:/SteamLibrary/steamapps/common/Factorio/data" --artifacts "./test-artifacts"
```

Fixture menguji query sensor dan serialisasi, lima patch resource dengan amount diketahui, nominal listrik/storage, jaringan logistik, kereta, jenis musuh, bot walk/craft/mine, state bersama, cursor/delta, subscription, RCON, action guard, serta save/reload. Fixture hanya masuk ke direktori mod sementara runner. Jangan memasang `tests/fixture` pada save permainan.

## Susunan sumber

`control.lua` menghubungkan lifecycle Factorio. `bridge/` menangani validasi, protocol, state persisten, event ring, dan subscription. `world/` berisi sensor terarah; `bot/` berisi registry dan primitive karakter. Perubahan pada dunia/state dibatasi pada adapter engine serta penyimpanan milik mod. Serializer hanya mengembalikan data JSON; tidak mengirim LuaObject kepada SDK.

Referensi yang menjadi dasar implementasi: [Factorio Runtime API 2.0.77](https://lua-api.factorio.com/2.0.77/), [LuaControl](https://lua-api.factorio.com/2.0.77/classes/LuaControl.html), [LuaFlowStatistics](https://lua-api.factorio.com/2.0.77/classes/LuaFlowStatistics.html).
