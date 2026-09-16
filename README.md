# pandatone

palette management for robots

> **Archived.** Pandatone was an attempt to create a small, sharp tool used
> that could be easily integrated to help manage consistent color usage across
> projects. It got heavy, fast. I learned a lot, but ultimately decided this
> was not the way to solve this particular set of problems.

A palette library as a Rails engine: named, tagged colors and the palettes
that hold them, with a versioned JSON API and a Ruby interface, so other tools
can ask two questions — give me the colors of the palette tagged `active`, and
which palettes contain `#E30613`.

## quickstart

```ruby
# Gemfile — not on RubyGems; taken from its main branch
gem "pandatone", github: "bobbymeyer/pandatone", branch: "main"

# config/routes.rb
mount Pandatone::Engine, at: "/pandatone"
```

```sh
bin/rails db:migrate        # the engine's migrations run with the host's
bin/rails pandatone:seed    # a small real library; idempotent
```

Tables are prefixed `pandatone_`. Written for SQLite — tags are queried with
`json_each`.

## what the host provides

| | |
| --- | --- |
| **The door** | Screens inherit the host's `ApplicationController`, API endpoints the host's `ApiController`. The engine never learns what a user is |
| **The shell** | The host's layout renders `its_swiss/shell` and places `yield :sections`, where Colors, Palettes and Lookup arrive |
| **The theme** | Accent, typeface, value scale, field count and baseline are the host's, set in its `theme.css` |
| **The script** | its-swiss registers its own Stimulus controllers; the engine registers its own. The host adds nothing to its importmap |

```ruby
# config/initializers/pandatone.rb — set before the engine loads
Pandatone.base_controller_class = "ApplicationController"   # default
Pandatone.api_base_controller_class = "ApiController"       # default
```

A host with no door sets these to `ActionController::Base` and
`ActionController::API`.

Inside an engine request the bare route helpers are the engine's, so a host
layout calls its own through `main_app`.

## Ruby interface

Plain arguments in, plain data out — the same hashes the API serializes, never
a record of the engine's. The API's read endpoints call these same methods.

| Call | Returns |
| --- | --- |
| `Pandatone.palette(key)` | One palette with its colors in order, by id or name |
| `Pandatone.palettes(tag:, containing:, q:, sort:)` | Palette summaries |
| `Pandatone.palette_colors(key, sort: nil)` | The colors of one palette, in the palette's order unless sorted |
| `Pandatone.colors(tag:, value:, in_palette:, q:, sort:)` | Colors |
| `Pandatone.lookup(query)` | `{ query:, hex:, rgb:, build:, colors:, palettes:, nearest: }` |
| `Pandatone.tags` | `{ colors: [...], palettes: [...] }` |

```ruby
Pandatone.palettes(tag: "active")
Pandatone.palettes(containing: "#E30613")
Pandatone.palette_colors("Brand Core")
Pandatone.lookup("227, 6, 19")
```

`containing` takes a hex, an RGB triple or a CMYK build. Sorts are `name`,
`added`, `modified`, `spectrum`, `dark`, `light`.

Anything else — `Pandatone::Palette.where(...)` — is reaching into the engine.

## HTTP API

Everything under `/api/v1`. JSON by default. Collections are bare arrays, no
envelope. A token in the header, never the session cookie.

| Route | Methods |
| --- | --- |
| `/api/v1/openapi` | `GET` — describes the API; not behind the token |
| `/api/v1/palettes` | `GET`, `POST` |
| `/api/v1/palettes/:id` | `GET`, `PATCH`, `DELETE` |
| `/api/v1/palettes/:id/colors` | `GET` |
| `/api/v1/colors` | `GET`, `POST` |
| `/api/v1/colors/:id` | `GET`, `PATCH`, `DELETE` |
| `/api/v1/lookup` | `GET` |
| `/api/v1/tags` | `GET` |

```sh
curl -H "Authorization: Bearer $PANDATONE_TOKEN" \
     https://example.com/pandatone/api/v1/palettes?tag=active
```

A color comes back as:

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

That shape, key order included, is pinned by a contract test. The way to
change v1 is to add v2.

### exports

Extensions on the palette routes.

| Extension | Gives |
| --- | --- |
| `.ase` | Adobe swatch exchange; each color in the space it was authored in |
| `.css` | Custom properties on `:root`, in the palette's order |

There is no export of the whole library — a palette is the unit with a name
and an order.

## the domain

Colors are first-class, not children of palettes. One brand blue used in ten
palettes is one row joined to ten palettes, which is what makes the reverse
lookup possible.

| Rule | Enforced |
| --- | --- |
| A color is its value — no two colors may render the same hex | At the write |
| No two palettes may hold exactly the same set of colors; order is not part of the identity | At the write |
| Near-duplicates inside a redmean distance of `32` (0–765 scale) | Warned, with a "create anyway" button |

Every color stores both RGB and CMYK. `source_space` records which was
authored; the other is redrawn on every write, so the two cannot drift. RGB
round-trips through CMYK losslessly, but many CMYK mixes collapse onto one RGB
triple.

## dresser

`Pandatone::Dresser` is how another tool composes in value — a pattern of
ranked slots — and asks what those values are wearing.

| Piece | Is |
| --- | --- |
| `Dresser::Catalog` | Every palette, fetched once from `Dresser.source` and filtered locally |
| `Dresser::Palette`, `Dresser::Color` | The wire format read back |
| `Dresser::Luminance` | OKLab L, so a palette ranks lightest first — slot 0 is the ground |
| `Dresser::Colorway`, `Dresser::Snapshot`, `Dresser::Rule` | Concerns for the consumer's own records |
| `Dresser::Drift` | Whether the palette has moved since, as a sentence. Reported, never applied |
| `Dresser::Dressing` | The controller's three lines: catalogue, palette, drift report |

Views and helpers: `pandatone/dresser/picker`, `pandatone/dresser/actions`,
`palette_strip`, `slot_swatch`, `rule_in_words`, and `pandatone/dresser.css`.

| Variable | Sets |
| --- | --- |
| `PANDATONE_URL` | Unset: the Pandatone in this process, through its public methods. Set: that Pandatone over HTTP |
| `PANDATONE_TOKEN` | The bearer token for the HTTP source |

```ruby
class Stripeclub::Colorway < ApplicationRecord
  include Pandatone::Dresser::Colorway
  belongs_to :pattern
  has_many :rules, class_name: "ValueRule", dependent: :destroy
  delegate :slot_count, to: :pattern
end
```

## not here

No color science. No ICC profiles, no Lab, no spot colors, no gamut mapping.
CMYK is stored and served, labeled an approximate device conversion.

## tech

Rails engine, v0.4.0. Ruby >= 3.2, Rails >= 8.0 and < 9. Propshaft, importmap,
Turbo, Stimulus and [its-swiss](https://github.com/bobbymeyer/its-swiss) >= 1.0
come with the gem. SQLite. Minitest.

```sh
bin/rails test      # 375 runs, 5199 assertions
```

System tests run through `rack_test` by default, so the suite needs no browser
and the app keeps working with JavaScript off.

## license

MIT.
