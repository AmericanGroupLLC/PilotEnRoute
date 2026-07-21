# CLAUDE.md

- Start with `AGENTS.md` (root) — dense AI map: what/run/architecture, file map, services, "where to change X", gotchas.
- Deeper architecture in `docs/DESIGN.md` (layers, modules, data/persistence, navigation, models, theme, platform, testing).
- Critical: run `flutter pub get` before `flutter analyze` (stale package_config causes ~12k phantom errors).
