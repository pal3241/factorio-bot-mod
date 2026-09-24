# Bot Action API

Semua mutation memerlukan `fbot-enable-actions`.

Virtual bot adalah Factorio `character` server-side, bukan akun Steam/player connection palsu.

## Lifecycle

### `bot.create`

Membuat character pada generated, collision-free position.

### `bot.destroy`

Menghapus virtual bot registry/entity sesuai implementasi bridge.

### `bot`

Query detail bot.

### `bots`

List virtual bots.

## Movement

### `bot.walk`

Bounded walking state dalam satu direction untuk sejumlah tick.

### `bot.stop`

Menghentikan walking/mining/shooting/picking/repair/vehicle bounded action yang dikelola bridge.

## Mining

### `bot.mine`

Menggunakan native character mining state terhadap posisi target.

Target harus valid dan reachable.

## Crafting

### `craftable`

Mengecek recipe availability/craftable count.

### `bot.craft`

Memulai native hand crafting.

## Building

### `bot.place`

Real placement:
- entity prototype harus ada.
- bot harus dalam build distance.
- collision check harus lolos.
- bot harus mempunyai placement item.
- placement item dikonsumsi.

### `bot.build-ghost`

Membuat construction ghost untuk workflow robot network.

### `bot.rotate`

Rotasi reachable entity.

### `bot.set-recipe`

Mengatur recipe reachable machine bila entity/runtime mendukungnya.

## Inventory & container

### `bot.inventory`

Membaca character inventories, crafting queue, selected gun, dan vehicle.

### `bot.transfer`

Arah:
- `to-entity`
- `from-entity`

Target entity harus reachable dan mempunyai inventory yang sesuai.

### `bot.drop`

Menghapus item dari inventory lalu spill ke world.

### `bot.pickup`

Mengaktifkan character picking state selama bounded ticks.

## Equipment

### `bot.equip`

Main inventory → explicit character inventory index.

### `bot.unequip`

Explicit character inventory index → main inventory.

Gunakan `capabilities.enums.inventory` untuk index yang benar.

## Combat

### `bot.select-gun`

Memilih gun slot.

### `bot.attack`

Menggunakan native shooting state. Bridge memeriksa `can_shoot`; weapon/ammo/range tetap aturan Factorio.

### `bot.repair`

Native repair state terhadap reachable target.

## Vehicle

### `bot.enter-vehicle`

Menetapkan character sebagai driver entity vehicle.

### `bot.leave-vehicle`

Keluar dari vehicle.

### `bot.drive`

Bounded riding state:
- acceleration enum
- direction enum
- ticks

Gunakan:
- `capabilities.enums.riding_acceleration`
- `capabilities.enums.riding_direction`

jangan menebak angka enum.

## Chat

### `chat.send`

Menulis pesan bot/server-side.

### Incoming chat

Incoming normal chat muncul sebagai `chat.message` dalam delta event log.

Slash command Factorio bukan chat event biasa.

## Mutation timeout

Jangan auto-retry mutation hanya karena transport timeout.

Urutan aman:
1. timeout terjadi.
2. query state.
3. tentukan apakah mutation sudah diterapkan.
4. retry hanya bila state menunjukkan belum diterapkan.

Ini mencegah double crafting, double transfer, atau duplicate placement.
