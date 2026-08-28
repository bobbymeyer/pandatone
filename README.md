# Pandatone

A palette library manager. It stores colour swatches and palettes, and serves
them over a small versioned JSON API so other tools can ask two questions
without knowing anything about how this app is built:

- *Give me the colours of the palette tagged `active`.*
- *Which palettes contain `#E30613`?*

It does that one job. There are no colour-science ambitions here: no ICC
profiles, no Lab, no spot colours, no gamut mapping. CMYK is stored and served
but is an approximate device conversion, and says so.

## Running it

```sh
bin/setup           # installs gems, prepares the database, seeds it
bin/rails server
bin/rails test:all  # models, requests, contract, system
```

Seeds are idempotent, so `bin/rails db:seed` can be re-run at any time.

## The domain

Colours are first-class, not children of palettes. One brand blue used across
ten seasonal palettes is **one** `Color` row joined to ten palettes through
`PaletteColor`, which is what makes discovery work in both directions.

Every colour stores **both** colour spaces. `source_space` records which one
was authored; the other is redrawn from it on every write, so the two cannot
drift apart. RGB round-trips through CMYK losslessly, but many CMYK mixes
collapse onto a single RGB triple — which is exactly why the source space is
recorded rather than inferred.

There is no `active` boolean anywhere. An active palette is one tagged
`active`. Tags are normalised to stripped, downcased, deduped strings.

## API

Everything lives under `/api/v1`. Collections are bare JSON arrays; there is
no envelope. Validation failures return `422` with `{"errors": {...}}`, and
missing records return `404` with `{"error": "Not found"}`.

| Verb   | Path                        | Notes                                                     |
| ------ | --------------------------- | --------------------------------------------------------- |
| GET    | `/palettes`                 | Filters: `?tag=`, `?color=RRGGBB` (with or without `#`), combinable |
| GET    | `/palettes/:id`             | Colours inline in position order. `:id` may be an id or a name |
| GET    | `/palettes/:id/colors`      | Just the colours. The workhorse endpoint                   |
| POST   | `/palettes`                 | Creates a palette with nested colours in one request       |
| PATCH  | `/palettes/:id`             | Updates name/tags; adds, removes and reorders colours      |
| DELETE | `/palettes/:id`             | Colours survive, since they may sit in other palettes      |
| GET    | `/colors`                   | Filters: `?tag=`, `?hex=RRGGBB`, `?palette=name-or-id`     |
| GET    | `/colors/:id`               | Includes a `palettes` array: the reverse lookup            |
| POST   | `/colors`                   | Creates a standalone colour                                |

A colour is serialised as:

```json
{
  "id": 12,
  "name": "signal-red",
  "hex": "#E30613",
  "rgb": { "r": 227, "g": 6, "b": 19 },
  "cmyk": { "c": 0.0, "m": 97.4, "y": 91.6, "k": 11.0 },
  "source_space": "rgb",
  "tags": ["brand", "primary"]
}
```

That shape is pinned by `test/controllers/api/v1/contract_test.rb`, including
key order. If that test fails, a downstream tool breaks: the fix is a `v2`,
not an edit.

### Writing colours to a palette

`POST` and `PATCH` take a `colors` array whose entries are either a reference
to a colour already in the library, or a full definition to create:

```json
{ "palette": { "name": "Autumn 2026", "tags": ["seasonal"],
  "colors": [ { "id": 12 },
              { "name": "moss", "source_space": "rgb", "r": 85, "g": 96, "b": 58 } ] } }
```

On `PATCH`, the array **replaces** the whole list in the order given, so one
request shape covers adding, removing and reordering. Omit the key to leave
the colours alone. The whole write is one transaction.

## Conventions

Rails 8, strictly omakase: Propshaft, importmap, Hotwire, SQLite, Minitest,
fixtures. No authentication — this is a local, single-user tool.

The CSS is hand-written plain CSS in the spirit of the Swiss International
Typographic Style, organised by concern (`grid`, `base`, `type`,
`components`, `transitions`). There is no framework and no utility-class
system in this repository. All spacing derives from the custom properties in
`grid.css`; the interface is near-monochrome so that the swatches are the only
colour on the page.

Navigation uses Turbo Drive with the View Transitions API. A swatch on the
palette index and the same swatch on the palette page share a
`view-transition-name`, so the browser morphs one into the other. Those names
key on the palette *membership* rather than the colour, because one colour can
appear in several strips on the index and a duplicate name silently disables
the morph. `prefers-reduced-motion` turns transitions off entirely.

## Tests

System tests run through `rack_test` by default, so the suite needs no browser
binary. That also keeps the app working with JavaScript off: Turbo Frames fall
back to full navigations, and the Stimulus live preview is enhancement on top
of a form that already submits. To run the same flows in a real browser:

```sh
SYSTEM_TEST_DRIVER=selenium bin/rails test:system
```
