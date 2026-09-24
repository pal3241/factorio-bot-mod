# Installation & Connection

## Requirements

- Factorio 2.x.
- Optional: Space Age.
- Factorio Bot World Bridge v0.5.x.
- RCON bila diakses dari SDK/process eksternal.

## Install mod

Salin repo/folder release sebagai:

```text
factorio-bot-mod_0.5.0
```

ke directory mods Factorio.

Windows default:

```text
%APPDATA%\Factorio\mods
```

Aktifkan **Factorio Bot World Bridge**, lalu load save.

Pada multiplayer, mod list harus sesuai pada server/client sesuai aturan Factorio.

## Verify

Dari admin console/RCON:

```text
/fbot {"api_version":1,"id":"hello","method":"capabilities","params":{}}
```

Response sukses berbentuk JSON envelope dengan:
- `api_version`
- `id`
- `tick`
- `cursor`
- `ok`
- `data`

## Enable actions

Default aman adalah sensor-oriented. Untuk mutation:

```text
/fbot-enable-actions
```

Matikan kembali:

```text
/fbot-disable-actions
```

Saat disabled, query world tetap bekerja tetapi create/walk/mine/place/combat/transfer/chat-send dan mutation lain ditolak.

## GUI-hosted Factorio

Headless server kedua tidak wajib. World dapat dijalankan dari Factorio desktop/GUI sebagai hosted multiplayer dan external SDK terhubung melalui RCON/local RCON configuration yang disediakan Factorio.

True single-player tanpa interface RCON tidak dapat menerima external SDK request dengan mekanisme ini.

## Dedicated/headless

Contoh:

```text
factorio --start-server factory.zip --rcon-bind 127.0.0.1:27015 --rcon-password REPLACE_ME
```

## Security

RCON adalah privileged interface. Jangan:
- bind ke public internet tanpa protection.
- commit password.
- menggunakan password lemah.

Prefer:
- loopback.
- trusted LAN.
- VPN.
- SSH/private tunnel.

## Version compatibility

Client sebaiknya selalu memanggil `capabilities` setelah connect dan memeriksa:
- mod version
- API version
- action availability
- supported methods
- enum values
- limits
- Space Age capability

Jangan hard-code riding/inventory enum numeric values bila capabilities sudah menyediakannya.
