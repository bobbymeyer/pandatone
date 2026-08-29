# Pandatone

A palette library manager. It stores color swatches and palettes, and serves
them over a small versioned JSON API so other tools can ask two questions
without knowing anything about how this app is built:

- *Give me the colors of the palette tagged `active`.*
- *Which palettes contain `#E30613`?*

It does that one job. There are no color-science ambitions here: no ICC
profiles, no Lab, no spot colors, no gamut mapping. CMYK is stored and served
but is an approximate device conversion, and says so.

## Running it

```sh
bin/setup           # installs gems, prepares the database, seeds it
bin/rails server
bin/rails test:all  # models, requests, contract, system
```

Seeds are idempotent, so `bin/rails db:seed` can be re-run at any time.

## The domain

Colors are first-class, not children of palettes. One brand blue used across
ten seasonal palettes is **one** `Color` row joined to ten palettes through
`PaletteColor`, which is what makes discovery work in both directions.

Every color stores **both** color spaces. `source_space` records which one
was authored; the other is redrawn from it on every write, so the two cannot
drift apart. RGB round-trips through CMYK losslessly, but many CMYK mixes
collapse onto a single RGB triple — which is exactly why the source space is
recorded rather than inferred.

There is no `active` boolean anywhere. An active palette is one tagged
`active`. Tags are normalized to stripped, downcased, deduped strings.

### One swatch per color, one palette per set

A library nobody trusts to be free of near-identical swatches is a library
nobody looks in, so duplication is stopped at the write rather than tidied up
afterward:

* **A color is its value.** No two `Color` rows may render the same hex —
  enforced by a validation and a unique index on `(r, g, b)`. A CMYK recipe
  that lands on a color already on file is held to the same line, because on
  screen it *is* that color. Without this the reverse lookup ("which palettes
  contain `#E30613`") would be an arbitrary choice between rows.
* **A palette is its set of colors.** No two palettes may hold exactly the
  same colors; a name is a label on a set, not part of it. Order is not part
  of the identity, and empty palettes do not duplicate one another. The check
  runs inside the same transaction as every other write, so removing a swatch
  is refused too if it would leave a duplicate behind.
* **Deleting is the same rule, backward.** A color is shared, so deleting
  one held by palettes rewrites every one of them — more than a button
  reading "delete color" suggests. It is refused until the request asks for
  it in those terms, and the refusal names the palettes. It is refused
  outright when stripping it would leave two palettes holding exactly the
  same colors, since that rule cannot be true only on the way in.
* **Starting from an existing palette carries, it does not copy.** A seasonal
  variant is usually last season's palette with a color swapped, and a saved
  clone is exactly the duplicate the rule forbids. "New from this" carries the
  swatches into the form as ticked boxes instead: untick what you do not want,
  or add a swatch, and what you save is already the palette you meant. Keeping
  everything and adding nothing is refused, in the same words as any other
  duplicate.
* **Near-duplicates are a question, not a rule.** Anything within a redmean
  distance of 32 of an existing swatch — `#FFFFFF` against `#FAFAF8` scores
  17 — is put back to you with both swatches side by side and a "create
  anyway" button. Redmean is a weighted RGB distance: it tracks how different
  two colors look far better than plain Euclidean RGB while staying pure
  arithmetic. No profiles, no Lab, no color science for a question that only
  needs an approximate answer. Two grays twenty steps apart score 60 and stay
  two swatches.

### Ordering

Both indexes sort by name, date added, date modified, color, dark first or
light first. The last three turn on what something looks like rather than on
what a column holds, so they are computed in Ruby over rows the page loads
anyway; name, added and modified stay in SQL.

Dark and light order by Rec. 601 luma — the standard weighted average of the
channels. It is not a perceptual lightness, but it puts yellow well above blue
where a plain mid-point calls them equal.

The **color** sort runs black, then ROYGBIV, then white. Colors with almost
no chroma are not on the spectrum at all, so they go to the two ends by which
half of the black-to-white axis they sit on, and everything with a hue runs
between them in hue order. A wheel has no beginning, so a linear list has to
cut it somewhere and two neighbors always land at opposite ends; the cut goes
in the gap between magenta and red rather than at red, because cutting at red
puts `#E30613` — a red that leans a few degrees blue, at hue 356.5 — after the
violets.

A palette has many colors, so it answers those two questions differently.
**Dark** and **light** average the luma of its swatches, because a palette is
dark or light as a whole rather than at its first swatch, and a scalar
averages honestly. **Color** reads the swatch the strip leads with, because
a hue cannot be averaged — the mean of red and violet is green — and the lead
swatch is the one anchoring the palette on every screen that shows it. A
palette holding no swatches sorts last under all three rather than pretending
to be black.

## Screens

The UI is for a human curating the library; the API is for machines.

- **Palettes** — the index as strips of swatches, filtered by tag and name; a
  palette page where swatches are reordered, removed and added in place.
- **Colors** — the whole library as swatches, filtered by tag and name, each
  showing the palettes it sits in; a color page with both spaces, its tags
  and its member palettes, editable from there. Editing a color changes it
  in every palette that holds it, which the edit form says before you commit.
- **Lookup** — paste a hex or an RGB triple and find every palette holding it.
  When the library holds no exact match it offers the closest color it does
  hold, with no threshold: "we do not have that, but we have this". The two
  swatches are shown, so how close *close* is stays a matter for your eye
  rather than a number nobody can interpret. If neither is what you wanted,
  "Add this color swatch" opens the entry form with the hex already in it.
  It reads a hex, an RGB triple or a CMYK build — four numbers are inks on
  0..100, three are channels on 0..255 — and matches on the RGB all three
  resolve to, so a search in one space finds a color authored in the other.
  A build says so on the result, because that conversion is lossy and the
  match is on the color it renders to, not on the build itself.

## API

Everything lives under `/api/v1`. Collections are bare JSON arrays; there is
no envelope. Validation failures return `422` with `{"errors": {...}}`, and
missing records return `404` with `{"error": "Not found"}`.

| Verb   | Path                        | Notes                                                     |
| ------ | --------------------------- | --------------------------------------------------------- |
| GET    | `/palettes`                 | Filters: `?tag=`, `?color=RRGGBB` (with or without `#`), combinable |
| GET    | `/palettes/:id`             | Colors inline in position order. `:id` may be an id or a name |
| GET    | `/palettes/:id/colors`      | Just the colors. The workhorse endpoint                   |
| POST   | `/palettes`                 | Creates a palette with nested colors in one request       |
| PATCH  | `/palettes/:id`             | Updates name/tags; adds, removes and reorders colors      |
| DELETE | `/palettes/:id`             | Colors survive, since they may sit in other palettes      |
| GET    | `/colors`                   | Filters: `?tag=`, `?hex=RRGGBB`, `?palette=name-or-id`     |
| GET    | `/colors/:id`               | Includes a `palettes` array: the reverse lookup            |
| POST   | `/colors`                   | Creates a standalone color                                |
| PATCH  | `/colors/:id`               | Edits a color. It is shared, so this changes every palette holding it |
| DELETE | `/colors/:id`               | Refused while a palette holds it unless `from_palettes` is sent |

A color is serialized as:

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

### Writing colors to a palette

`POST` and `PATCH` take a `colors` array whose entries are either a reference
to a color already in the library, or a full definition to create:

```json
{ "palette": { "name": "Autumn 2026", "tags": ["seasonal"],
  "colors": [ { "id": 12 },
              { "name": "moss", "source_space": "rgb", "r": 85, "g": 96, "b": 58 } ] } }
```

On `PATCH`, the array **replaces** the whole list in the order given, so one
request shape covers adding, removing and reordering. Omit the key to leave
the colors alone. The whole write is one transaction.

### Ordering over the API

Both index endpoints take `?sort=` with the same keys the interface uses:
`name` (the default), `added`, `modified`, `spectrum`, `dark`, `light`. An
unrecognized one is name rather than an error.

`GET /palettes/:id/colors` defaults to the palette's own sequence instead,
because that order is the thing being published; pass `?sort=` to override it.

### Duplicates over the API

The API applies the same rules as the interface. An exact duplicate color, or
a palette holding exactly another palette's colors, comes back `422` with the
reason under `errors.base`.

A near-duplicate color also comes back `422`, with the swatch it resembles
serialized under a `similar` key so the client can show it. Send the same
request again with a top-level `"confirm_similar": true` to create it anyway:

```json
{ "confirm_similar": true,
  "color": { "name": "off-white", "source_space": "rgb", "r": 255, "g": 255, "b": 255 } }
```

## Conventions

Rails 8, strictly omakase: Propshaft, importmap, Hotwire, SQLite, Minitest,
fixtures. No authentication — this is a local, single-user tool.

The CSS is hand-written plain CSS in the spirit of the Swiss International
Typographic Style, organized by concern (`grid`, `base`, `type`,
`components`, `transitions`). There is no framework and no utility-class
system in this repository. The typeface is Archivo, shipped in
`app/assets/fonts` as a single variable Latin subset rather than pulled from
a font CDN, so the app renders correctly with nothing external reachable. All spacing derives from the custom properties in
`grid.css`; the interface is near-monochrome so that the swatches are the only
color on the page.

Two signals never rest on color alone. The current filter and the current
order carry weight as well as the accent, because this is a color tool and a
reader who cannot separate red from gray would otherwise have no current
state at all. And a destructive action is set apart from the ones beside it
by a gap before it is colored on hover, because a gap is read before a word
is. Both are pinned by stylesheet tests, and the separation by a rendered one
— the rule for it existed and did nothing for a while, since `button_to`
wraps its button in a form and an auto margin belongs to the flex child.

Searching, filtering and ordering are three registers of one block: a label
in a shared column, then the control. Every one of those labels is set in the
same micro register as every other label in the app, pinned by a test — the
two newest came out a step larger than the choices they label, which is
backward. The column width is a single custom
property, so all three line up by construction rather than by coincidence.
Filtering and ordering are also the same kind of control — pick one of a
handful — so they are built from one partial. Tags
on a card are the same links as the tags in the filter bar, because they are
the same thing: the library's whole discovery mechanism.

Headings follow one rule: the page title is `h1`, a section heading is `h2`,
and an item's name sits one level under whatever heading it belongs to. A
system test walks every page and fails on a skipped level.

Navigation uses Turbo Drive with the View Transitions API. A swatch on the
palette index and the same swatch on the palette page share a
`view-transition-name`, so the browser morphs one into the other. Those names
key on the palette *membership* rather than the color, because one color can
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
