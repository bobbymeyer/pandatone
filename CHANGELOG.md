# Changelog

Semver. The API is versioned separately, under its own path, and is not
what this file numbers.

## 0.2.0 — 2026-09-07

### Added

- **The palette dresser.** `Pandatone::Dresser` is the consumer's side of
  Pandatone: a catalogue of palettes read in the wire format, each colour
  measured for how light it looks so a palette ranks paper to ink; a
  snapshot taken at the moment a palette is chosen; a rule per slot over
  that snapshot rather than a hex; and drift, asked for and reported, never
  applied. Stripeclub wrote it first and Badger copied it, and a pattern
  that appears in two consumers belongs to the thing they consume. A
  consumer includes `Dresser::Colorway`, `Dresser::Snapshot` and
  `Dresser::Rule` in its own records, mixes `Dresser::Dressing` into its
  controller, and renders the picker and the swatches with
  `pandatone/dresser/*` and the helpers `palette_strip`, `slot_swatch`
  and `rule_in_words`. `pandatone/dresser.css` goes beside the consumer's
  own stylesheets. With no `PANDATONE_URL` the Pandatone in the same process
  answers through its public methods; with one, that Pandatone answers over
  HTTP.

### Changed

- **Set on its-swiss 0.8.** The page head, the filter block, the card list
  and the live search are the library's now, and the engine's own copies
  are gone: `page_head` on every page, `search_form` and `filter_register`
  on the two indexes and the library picker, `.cards` under them. The
  choice in force carries `aria-current` rather than `.tag.active`. The
  host registers `its-swiss-live-search` beside the clipboard; the engine
  no longer ships a live search controller of its own.
- **Every form is written by the library's builder**, so a refused field is
  refused where it stands, with the label, the hint and the error wired to
  the control. The swatch entry row is written under its own `swatch`
  scope, whatever record the form around it is for.
- `--baseline` is `--swatch-step`: half a space unit, a third of a line, and
  not a baseline. `--register-label` is the library's `--filter-label`.

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
