# Changelog

Semver. The API is versioned separately, under its own path, and is not
what this file numbers.

## 0.1.0 — 2026-09-04

Pandatone becomes a Rails engine. Everything that knows what a swatch is
comes along; everything that does not stays behind.

- **A mountable engine, isolated.** Every constant under `Pandatone`, every
  table under `pandatone_`, every route under the mount. Its migrations run
  with the host's; its stylesheets and its two Stimulus controllers arrive
  through its own layout, which renders the host's around them.
- **The door is the host's.** Users, sessions, invitations, the People page,
  the account page and the API token are gone: the engine's controllers
  inherit from the host's (`Pandatone.base_controller_class`,
  `Pandatone.api_base_controller_class`), and whatever those refuse, the
  engine refuses. Read-only tokens went with them; a host that wants them
  puts them on its own door.
- **The theme is the host's.** Archivo, the signal-red accent and the warm
  greys were Pandatone's own slots; they are the host's to set now, and the
  engine keeps only what it measures — the card widths, the second density,
  the swatch row.
- **A Ruby interface.** `Pandatone.palette`, `.palettes`, `.palette_colors`,
  `.colors`, `.lookup` and `.tags` answer with the same plain hashes the API
  serializes, and the API's read endpoints call them.
- **The API describes itself.** `GET /api/v1/openapi` serves an OpenAPI 3.1
  description, open to anyone, and a test holds it and the routes to each
  other.
- **Sections, not a nav.** The engine offers Colors, Palettes and Lookup to
  the host through `content_for :sections`; the masthead, the mark and the
  way out are the host's.
