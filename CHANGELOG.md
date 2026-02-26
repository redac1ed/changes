# Changelog

## [2.0.0] - 2026-02-26

### Added
- **Game State Enhanced**: Complete rewrite of the save system.
    - Slot-based saving (JSON).
    - Detailed stats tracking (shots, time, stars).
    - Unlockables management (skins, trails).
    - Settings persistence.
- **Achievement System**: robust achievement tracking with UI toasts.
    - 20+ defined achievements.
    - Category system (Progression, Skill, Collection, Secret).
- **Procedural Level Generation**: New `LevelBuilder` class.
    - Generates infinite levels based on difficulty.
    - Supports multiple platform types (Static, Moving, Bounce, Crumbling).
    - Auto-decoration placement.
- **Advanced Enemies**:
    - `JumperEnemy`: Hops around unpredictably.
    - `ExplodingEnemy`: Self-destructs near player.
    - Base class refactored for better state management.
- **UI Overhaul**:
    - `MenuManager`: Stack-based menu navigation.
    - `ShopMenu`: In-game store for skins and abilities.
    - `LevelSelectMenu`: Dynamic grid based on unlock status.
    - `SettingsMenu`: Comprehensive audio/video options.
    - Enhanced Title Screen with "Shop" and "Daily Challenge" hooks.
- **Particle System**:
    - Centralized `ParticleManager` with object pooling.
    - New effects: Confetti, Dust, Water Splash, Large Explosion.
- **Player Upgrades**:
    - `PlayerSkinManager`: Support for texture and shader-based skins.
    - `PlayerAbilityManager`: Boost, Brake, Shield, Ghost abilities.

### Changed
- **Level 1**: Remastered with fireflies, tutorial popups, and improved visuals.
- **Project Structure**: Updated `project.godot` to use new Autoloads.
- **Audio**: Improved `AudioManager` with dynamic mixing and spatial sound helpers.

### Technical
- Implemented event bus pattern via signals in `GameState`.
- Added debug tools for level generation.
- Optimized particle rendering with pooling.
- Standardized code style with clear region markers.

---

## Developer Notes

### Save Data Structure
Save files are stored in `user://save_slot_N.json`. Structure:
```json
{
  "meta": { ... },
  "progression": { "current_world": 1, ... },
  "currency": { "coins": 100 },
  "unlockables": { "skins": ["default", "magma"] },
  "levels": { "w1_l1": { "stars": 3 } }
}
```

### Adding Content
- **New Skin**: Add entry to `PlayerSkinManager.SKINS`.
- **New Achievement**: Add entry to `AchievementSystem.ACHIEVEMENTS`.
- **New Level**: Use `LevelTemplateEnhanced` and override `_build_level`.

### Known Issues
- Procedural generation might occasionally create impossible jumps at very high difficulties.
- Shop UI uses placeholder prices; ensure economy balance.
