# Factorio Bot World Bridge Documentation

Dokumentasi mod dibagi menjadi beberapa bagian:

- [Installation & Connection](installation.md) — instalasi, RCON, GUI-hosted world, security.
- [World Sensor API](world-api.md) — surfaces, terrain, entities, resources, electricity, logistics, production, research, trains, threats, players.
- [Bot Action API](actions-api.md) — movement, mining, crafting, inventory, equipment, building, combat, repair, vehicle, chat.
- [Protocol Reference](protocol.md) — request/response envelope, methods, pagination, event cursor, watches, Space Age details.

## Prinsip desain

World bridge adalah authoritative adapter antara external bot SDK dan Factorio runtime.

```text
External SDK
    │
    ▼
RCON / command bridge
    │
    ▼
Factorio Bot World Bridge
    │
    ├── sensors
    ├── event log
    ├── virtual characters
    └── safe action primitives
    │
    ▼
Factorio runtime
```

Mod **tidak** berisi LLM, planner, memory, atau autonomous AI. Itu sengaja diletakkan pada application/SDK layer.

## Version

Dokumentasi ini menargetkan **v0.5.x**.
