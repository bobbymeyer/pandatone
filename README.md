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

### One swatch per colour, one palette per set

A library nobody trusts to be free of near-identical swatches is a library
nobody looks in, so duplication is stopped at the write rather than tidied up
afterwards:

* **A colour is its value.** No two `Color` rows may render the same hex —
  enforced by a validation and a unique index on `(r, g, b)`. A CMYK recipe
  that lands on a colour already on file is held to the same line, because on
  screen it *is* that colour. Without this the reverse lookup ("which palettes
  contain `#E30613`") would be an arbitrary choice between rows.
* **A palette is its set of colours.** No two palettes may hold exactly the
  same colours; a name is a label on a set, not part of it. Order is not part
  of the identity, and empty palettes do not duplicate one another. The check
  runs inside the same transaction as every other write, so removing a swatch
  is refused too if it would leave a duplicate behind.
* **Near-duplicates are a question, not a rule.** Anything within a redmean
  distance of 32 of an existing swatch — `#FFFFFF` against `#FAFAF8` scores
  17 — is put back to you with both swatches side by side and a "create
  anyway" button. Redmean is a weighted RGB distance: it tracks how different
  two colours look far better than plain Euclidean RGB while staying pure
  arithmetic. No profiles, no Lab, no colour science for a question that only
  needs an approximate answer. Two greys twenty steps apart score 60 and stay
  two swatches.

## Screens

The UI is for a human curating the library; the API is for machines.

- **Palettes** — the index as strips of swatches, filtered by tag and name; a
  palette page where swatches are reordered, removed and added in place.
- **Colours** — the whole library as swatches, filtered by tag and name, each
  showing the palettes it sits in; a colour page with both spaces, its tags
  and its member palettes, editable from there. Editing a colour changes it
  in every palette that holds it, which the edit form says before you commit.
- **Lookup** — paste a hex or an RGB triple and find every palette holding it.
  When the library holds no exact match it offers the closest colour it does
  hold, with no threshold: "we do not have that, but we have this". The two
  swatches are shown, so how close *close* is stays a matter for your eye
  rather than a number nobody can interpret.

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
| PATCH  | `/colors/:id`               | Edits a colour. It is shared, so this changes every palette holding it |

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

### Duplicates over the API

The API applies the same rules as the interface. An exact duplicate colour, or
a palette holding exactly another palette's colours, comes back `422` with the
reason under `errors.base`.

A near-duplicate colour also comes back `422`, with the swatch it resembles
serialised under a `similar` key so the client can show it. Send the same
request again with a top-level `"confirm_similar": true` to create it anyway:

```json
{ "confirm_similar": true,
  "color": { "name": "off-white", "source_space": "rgb", "r": 255, "g": 255, "b": 255 } }
```

## Conventions

Rails 8, strictly omakase: Propshaft, importmap, Hotwire, SQLite, Minitest,
fixtures. No authentication — this is a local, single-user tool.

The CSS is hand-written plain CSS in the spirit of the Swiss International
Typographic Style, organised by concern (`grid`, `base`, `type`,
`components`, `transitions`). There is no framework and no utility-class
system in this repository. The typeface is Archivo, shipped in
`app/assets/fonts` as a single variable Latin subset rather than pulled from
a font CDN, so the app renders correctly with nothing external reachable. All spacing derives from the custom properties in
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
of a form that already submits.

`rack_test` has no CSS, no box model and no JavaScript, though, so it will
happily pass a page whose layout has collapsed. The same flows run in a real
browser too, and `test/system/browser_test.rb` adds the checks that only mean
something there — measured widths, the live preview, the `:has()` panels:

```sh
SYSTEM_TEST_DRIVER=selenium bin/rails test:system
```

Selenium Manager will fetch a driver to match the browser it finds. On a
machine that already has both, point at them instead:

```sh
SYSTEM_TEST_DRIVER=selenium \
  CHROME_BINARY=/path/to/chrome CHROMEDRIVER=/path/to/chromedriver \
  bin/rails test:system
```

CI runs both: `system-test` through `rack_test`, `browser-test` in Chrome.
