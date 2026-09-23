---@meta

---Model data protocol; tidak mempunyai kode runtime.
---@class PageQuery
---@field offset integer
---@field limit integer

---@class AreaQuery: PageQuery
---@field surface string
---@field force string
---@field area BoundingBox

---@class ForceQuery: PageQuery
---@field force string

---@class BotQuery
---@field id string

---@class EntityQuery
---@field surface string
---@field name string
---@field position MapPosition
---@field unit_number integer

---@class CreateBotQuery: BotQuery
---@field network string
---@field surface string
---@field force string
---@field position MapPosition

---@class WalkQuery: BotQuery
---@field direction integer
---@field ticks integer

---@class MineQuery: BotQuery
---@field position MapPosition
---@field ticks integer

---@class CraftableQuery: BotQuery
---@field recipe string

---@class BuildGhostQuery: BotQuery
---@field name string
---@field position MapPosition
---@field direction defines.direction

---@class CraftQuery: CraftableQuery
---@field count integer

---@class SharedQuery: PageQuery
---@field network string

---@class SharedWriteQuery
---@field network string
---@field key string
---@field value string
---@field expected_revision integer

---@class DeltaQuery
---@field after integer
---@field limit integer

---@class WatchQuery: BotQuery
---@field topic string
---@field interval integer
---@field query AreaQuery|ForceQuery|PageQuery|EntityQuery|BotQuery

---@class BridgeError
---@field code string
---@field message string

---@class Page<T>
---@field items T[]
---@field total integer
---@field next_offset integer?

---@class EntitySummary
---@field unit_number integer?
---@field name string
---@field type string
---@field position MapPosition
---@field surface string
---@field force string
---@field direction defines.direction
---@field quality string
---@field health number?
---@field max_health number?
---@field status defines.entity_status?
---@field ghost_name string?
---@field bounding_box BoundingBox

---@class InventoryView
---@field index integer
---@field slots integer
---@field contents ItemWithQualityCount[]

---@class MachineView
---@field recipe string?
---@field progress number
---@field speed number
---@field products_finished integer
---@field crafting boolean

---@class InserterView
---@field pickup_position MapPosition
---@field drop_position MapPosition
---@field held ItemWithQualityCount?

---@class BeltLineView
---@field index integer
---@field contents ItemWithQualityCount[]

---@class BeltView
---@field speed_tiles_per_tick number
---@field lines BeltLineView[]

---@class BurnerView
---@field remaining_burning_fuel_j number
---@field currently_burning string?

---@class EntityDetail: EntitySummary
---@field inventories InventoryView[]
---@field energy_j number
---@field buffer_capacity_j number?
---@field electric_network_id integer?
---@field fluids table<string, number>
---@field collision_mask CollisionMask
---@field amount integer?
---@field machine MachineView?
---@field mining_target EntitySummary?
---@field inserter InserterView?
---@field belt BeltView?
---@field burner BurnerView?
---@field ghost GhostView?

---@class GhostView
---@field ghost_name string
---@field construction_registered boolean
---@field required_items ItemWithQualityCount[]

---@class ResourcePatch
---@field query_local_id string
---@field name string
---@field position MapPosition
---@field bounds BoundingBox
---@field tile_count integer
---@field observed_amount number
---@field estimated_amount number
---@field touches_query_boundary boolean

---@class ResourcePage: Page<ResourcePatch>
---@field scope string
---@field connectivity string

---@class SurfaceView
---@field index integer
---@field name string
---@field daytime number
---@field darkness number
---@field peaceful_mode boolean
---@field solar_power_multiplier number
---@field pollutant_type string?

---@class ChunkView
---@field x integer
---@field y integer
---@field generated boolean
---@field charted boolean
---@field visible boolean
---@field pollution number

---@class TileView
---@field position MapPosition
---@field name string
---@field generated boolean
---@field collision_mask CollisionMask
---@field character_placeable boolean

---@class TerrainPage: Page<TileView>
---@field passability_semantics string

---@class PrerequisiteView
---@field name string
---@field researched boolean

---@class TechnologyView
---@field name string
---@field researched boolean
---@field enabled boolean
---@field available boolean
---@field prerequisites PrerequisiteView[]
---@field level integer
---@field progress number?
---@field unit_count integer?
---@field unit_energy_ticks number?
---@field ingredients Ingredient[]
---@field trigger ResearchTrigger?

---@class ResearchPage: Page<TechnologyView>
---@field current string?
---@field progress number
---@field queue string[]

---@class RecipeView
---@field name string
---@field enabled boolean
---@field hidden boolean
---@field category string
---@field energy_seconds number
---@field ingredients Ingredient[]
---@field products Product[]
---@field surface_conditions SurfaceCondition[]?

---@class ProductionView
---@field kind 'item'|'fluid'
---@field name string
---@field produced_total number
---@field consumed_total number
---@field produced_per_minute number
---@field consumed_per_minute number

---@class ProductionPage: Page<ProductionView>
---@field scope string
---@field quality_semantics string

---@class ActionView
---@field kind 'walk'|'mine'
---@field direction integer?
---@field position MapPosition?
---@field until_tick integer

---@class BotRecord
---@field id string
---@field network string
---@field entity LuaEntity
---@field created_tick integer
---@field action ActionView?

---@class BotView
---@field id string
---@field network string
---@field alive boolean
---@field created_tick integer
---@field entity EntitySummary?
---@field action ActionView?

---@class BotDetail
---@field id string
---@field network string
---@field entity EntityDetail
---@field crafting_queue CraftingQueueItem[]?
---@field crafting_progress number
---@field action ActionView?

---@class PlayerView
---@field index integer
---@field name string
---@field connected boolean
---@field force string
---@field surface string
---@field position MapPosition
---@field controller_type defines.controllers
---@field character EntitySummary?

---@class SharedEntry
---@field network string
---@field key string
---@field value string
---@field revision integer
---@field tick integer

---@class IdentityResult
---@field id string
---@field unit_number integer?

---@class CraftableResult
---@field recipe string
---@field enabled boolean
---@field count integer

---@class CraftResult
---@field started integer

---@class BuildGhostResult
---@field id string
---@field ghost_unit_number integer
---@field name string
---@field surface string
---@field force string
---@field position MapPosition
---@field direction defines.direction
---@field construction_registered boolean
---@field required_items ItemWithQualityCount[]

---@class ElectricMeasurement
---@field scope string
---@field window_seconds integer
---@field production_w number
---@field consumption_w number
---@field includes_accumulator_flows boolean

---@class GeneratorView
---@field unit_number integer
---@field name string
---@field status defines.entity_status
---@field nominal_w number
---@field energy_buffer_j number
---@field fluids table<string, number>

---@class AccumulatorView
---@field unit_number integer
---@field energy_j number
---@field capacity_j number

---@class UnavailableValue
---@field available false
---@field reason string

---@class ElectricView
---@field network_id integer
---@field members_observed integer
---@field generators GeneratorView[]
---@field accumulators AccumulatorView[]
---@field observed_storage_j number
---@field observed_storage_capacity_j number
---@field observed_nominal_generation_w number
---@field member_scope string
---@field satisfaction UnavailableValue
---@field measured ElectricMeasurement?

---@class EntityIdentity
---@field unit_number integer
---@field name string
---@field position MapPosition

---@class LogisticCellView
---@field owner EntityIdentity
---@field logistic_radius number
---@field construction_radius number
---@field charging integer
---@field awaiting_charge integer

---@class LogisticView
---@field network_id integer
---@field scope string
---@field logistic_robots integer
---@field construction_robots integer
---@field available_logistic_robots integer
---@field available_construction_robots integer
---@field contents ItemWithQualityCount[]
---@field cells LogisticCellView[]

---@class TrainView
---@field id integer
---@field state defines.train_state
---@field speed_tiles_per_tick number
---@field manual_mode boolean
---@field has_path boolean
---@field carriages EntityIdentity[]
---@field station EntityIdentity?
---@field schedule TrainSchedule?
---@field contents ItemWithQualityCount[]
---@field fluids table<string, number>

---@class ThreatView: EntitySummary
---@field distance_from_area_centre number
---@field pollution_at_position number
---@field attack_parameters AttackParameters?
---@field resistances table<string, Resistance>?
---@field absorptions_to_join_attack table<string, number>?
---@field is_military_target boolean

---@class HostileForceView
---@field name string
---@field evolution number

---@class ThreatPage: Page<ThreatView>
---@field hostile_forces HostileForceView[]
---@field pollution_at_centre number
---@field peaceful_mode boolean
---@field scope string

---@class SnapshotView
---@field scope string
---@field chunks Page<ChunkView>
---@field entities Page<EntitySummary>
---@field resources ResourcePage
---@field electric Page<ElectricView>
---@field logistics Page<LogisticView>
---@field threats ThreatPage
---@field research ResearchPage
---@field bots Page<BotView>
---@field players Page<PlayerView>
---@field production ProductionPage
---@field trains Page<TrainView>

---@class EventPayload
---@field id string?
---@field topic string?
---@field reason string?
---@field event integer?
---@field entity EntitySummary?
---@field action ActionView?
---@field surface string?
---@field surface_index integer?
---@field position ChunkPosition?
---@field area BoundingBox?
---@field force string?
---@field technology string?
---@field player_index integer?
---@field recipe string?
---@field started integer?
---@field error BridgeError?
---@field network string?
---@field key string?
---@field value string?
---@field revision integer?
---@field tick integer?

---@class BridgeEvent
---@field sequence integer
---@field tick integer
---@field kind string
---@field data EventPayload

---@class DeltaView
---@field items BridgeEvent[]
---@field next_cursor integer
---@field head_cursor integer
---@field has_more boolean

---@alias SensorView Page<SurfaceView>|Page<ChunkView>|Page<EntitySummary>|EntityDetail|TerrainPage|ResourcePage|Page<ElectricView>|Page<LogisticView>|Page<TrainView>|ProductionPage|ResearchPage|Page<RecipeView>|ThreatPage|Page<PlayerView>|Page<BotView>|BotDetail|CraftableResult|Page<SharedEntry>|DeltaView
---@alias QueryParams AreaQuery|ForceQuery|PageQuery|EntityQuery|BotQuery|CraftableQuery|SharedQuery|DeltaQuery
---@alias MutationParams CreateBotQuery|WalkQuery|MineQuery|CraftQuery|BotQuery|SharedWriteQuery

---@class WatchRecord
---@field id string
---@field topic string
---@field query QueryParams
---@field interval integer
---@field next_tick integer
---@field fingerprint string

---@class WatchResult
---@field id string
---@field initial SensorView
---@field interval integer

---@class BridgeState
---@field schema integer
---@field bots table<string, BotRecord>
---@field shared table<string, SharedEntry>
---@field watches table<string, WatchRecord>
---@field events table<integer, BridgeEvent>
---@field sequence integer
---@field budget_tick integer
---@field budget_used integer

---@class BridgeLimits
---@field area_side integer
---@field entities_scanned integer
---@field page integer
---@field event_retention integer
---@field subscriptions integer
---@field bots integer
---@field request_bytes integer
---@field response_bytes integer

---@class BridgeEnums
---@field direction table<string, integer>
---@field entity_status table<string, integer>
---@field train_state table<string, integer>
---@field inventory table<string, integer>

---@class CapabilitiesView
---@field mod_version string
---@field api_version integer
---@field minimum_factorio string
---@field query_methods string[]
---@field action_methods string[]
---@field additional_methods string[]
---@field actions_enabled boolean
---@field enums BridgeEnums
---@field limits BridgeLimits
---@field observation string
---@field virtual_bot string
---@field event_semantics string

---@alias BridgeData SensorView|SnapshotView|CapabilitiesView|WatchResult|IdentityResult|SharedEntry|ActionView|CraftResult|BuildGhostResult

---@class BridgeRequest
---@field api_version integer
---@field id string
---@field method string
---@field params QueryParams|MutationParams|WatchQuery

---@class BridgeResponse
---@field api_version integer
---@field id string?
---@field tick integer?
---@field cursor integer?
---@field ok boolean
---@field data BridgeData?
---@field error BridgeError?
