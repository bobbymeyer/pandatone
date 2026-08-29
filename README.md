# Pandatone

A palette library manager. It stores color swatches and palettes and serves
them over a small versioned JSON API, so other tools can ask two questions:

- *Give me the colors of the palette tagged `active`.*
- *Which palettes contain `#E30613`?*

That is the whole job. No ICC profiles, no Lab, no spot colors, no gamut
mapping. CMYK is stored and served, but it is an approximate device
conversion and says so.

## Running it

```sh
bin/setup           # gems, database, seeds
bin/rails server
bin/rails test:all
```

Seeds are idempotent and make no account. The first person to open the app is
sent to sign up, and that account is the admin.

## Accounts

Everything is behind a sign-in: the interface on a session cookie, the API on
a per-user token. `/up` stays open, because a load balancer has no token.

Sign-ups close behind the first account. After that, an admin invites by
address on **People** (linked from the account page), optionally as another
admin. Only an invited address may sign up, and signing up spends the
invitation. An admin can withdraw an invitation or remove an account, but not
their own.

Passwords are 8 characters, minimum. There is no character-class rule.

The API token is on the account page. Regenerating it there is the whole of
revocation — whatever held the old one stops working, nothing else changes.
It is separate from the password so a tool can be revoked on its own, and so
the password never goes into a cron line.

Mail is yours to supply: point `config.action_mailer.smtp_settings` at
whatever you run. Only "forgot your password" needs it; until then, reset in
`bin/rails console`.

## The domain

Colors are first-class, not children of palettes. One brand blue used in ten
palettes is **one** `Color` row joined to ten palettes through `PaletteColor`,
which is what makes the reverse lookup possible.

Every color stores **both** spaces. `source_space` records which was authored;
the other is redrawn on every write, so the two cannot drift. RGB round-trips
through CMYK losslessly, but many CMYK mixes collapse onto one RGB triple —
which is why the source space is recorded rather than inferred.

There is no `active` boolean. An active palette is one tagged `active`. Tags
are stripped, downcased and deduped.

### Duplicates are refused at the write

* **A color is its value.** No two colors may render the same hex — a
  validation and a unique index on `(r, g, b)`. Otherwise the reverse lookup
  would be an arbitrary choice between rows.
* **A palette is its set of colors.** No two palettes may hold exactly the
  same colors. Order is not part of the identity. Removing a swatch is
  refused too if it would leave a duplicate behind.
* **Deleting is that rule backward.** Deleting a color held by palettes
  rewrites all of them, so it is refused until the request asks for it in
  those terms, and refused outright if it would leave two palettes identical.
* **"New from this" carries, it does not copy.** The swatches arrive in the
  form as ticked boxes: untick, or add, and what you save is already a
  different palette. Saving it unchanged is refused like any duplicate.
* **Near-duplicates are a question, not a rule.** Within a redmean distance
  of 32 — `#FFFFFF` against `#FAFAF8` scores 17 — you get both swatches side
  by side and a "create anyway" button. Redmean is weighted RGB: it tracks
  how different two colors look far better than plain Euclidean distance
  while staying arithmetic.

### Ordering

Both indexes sort by name, added, modified, color, dark or light. The last
three turn on what something looks like, so they are computed in Ruby over
rows the page loads anyway; the rest stay in SQL.

Dark and light use Rec. 601 luma. Not perceptual, but it puts yellow above
blue where a plain mid-point calls them equal.

**Color** runs black, then ROYGBIV, then white. Near-neutral colors are not on
the spectrum, so they go to whichever end of the black-to-white axis they sit
on. A wheel has no beginning, so the cut goes between magenta and red rather
than at red — cutting at red puts `#E30613`, at hue 356.5, after the violets.

A palette answers differently: **dark** and **light** average its swatches,
since a palette is dark as a whole; **color** reads the swatch it leads with,
since hue cannot be averaged (the mean of red and violet is green). An empty
palette sorts last under all three.

## Screens

- **Colors** — the library as swatches, filtered by tag and name, each showing
  the palettes it sits in. A color page carries both spaces, its tags and its
  palettes. Editing a color changes every palette holding it, which the form
  says before you commit.
- **Palettes** — the index as strips of swatches. A palette page is one row
  divided by its own count, whatever that count is; choosing a swatch shows
  its values below the row, and reorders, removes or opens it. Which swatch
  is chosen is in the URL.
- **Lookup** — paste a hex, an RGB triple or a CMYK build (four numbers are
  inks on 0..100, three are channels on 0..255) and find every palette holding
  it. With no exact match it offers the nearest color on file, both swatches
  shown, so how close *close* is stays a matter for your eye. "Add this color
  swatch" opens the entry form with the value already in it.
- **Account** — who you are, your API token, and the buttons that end either.
- **People** — admin only: who has an account, who has been invited, and the
  field that invites another.

Both indexes offer **Small** and **Large** cards. Small is the default and
half the width, so the library reads as a library rather than as six cards.

## Exports

A palette leaves as `.ase` or `.css` — between them, a design tool and a
stylesheet. Same URL as the palette, asked for by extension.

```sh
curl -H "Authorization: Bearer $PANDATONE_TOKEN" \
     -O https://pandatone.example.com/api/v1/palettes/Brand%20Core.ase
```

**`.ase`** is Adobe Swatch Exchange. The palette becomes a named group, and
each color goes out in the space it was authored in — flattening a CMYK build
to RGB would throw away the one thing the row knows that its hex does not.

**`.css`** is custom properties on `:root` in the palette's order. CSS has no
CMYK, so an ink-authored color goes out as the hex it renders to and says so
in a comment. Names are made safe, and two swatches sharing one are kept
apart.

There is no export of the whole library. A palette is the unit with a name
and an order, which is what both formats are for.

## API

Everything is under `/api/v1`. Collections are bare arrays, no envelope.
`422` with `{"errors": {...}}`, `404` with `{"error": "Not found"}`, `401`
with `{"error": "Unauthorized"}`.

```sh
curl -H "Authorization: Bearer $PANDATONE_TOKEN" \
     https://pandatone.example.com/api/v1/palettes?tag=active
```

`Token` works as well as `Bearer`. The session cookie is deliberately not
accepted, or any page on the internet could drive this API from a signed-in
browser. The API does the color work; accounts and invitations are the
interface's business.

| Verb   | Path                   | Notes |
| ------ | ---------------------- | ----- |
| GET    | `/palettes`            | `?q=` name, `?tag=`, `?color=RRGGBB`, combinable |
| GET    | `/palettes/:id`        | Colors inline in position order. `:id` may be an id or a name |
| GET    | `/palettes/:id.ase`    | The palette as an Adobe swatch file |
| GET    | `/palettes/:id.css`    | The palette as custom properties |
| GET    | `/palettes/:id/colors` | Just the colors. The workhorse |
| POST   | `/palettes`            | Creates a palette with nested colors in one request |
| PATCH  | `/palettes/:id`        | Name, tags, and the whole color list |
| DELETE | `/palettes/:id`        | Colors survive; they may sit elsewhere |
| GET    | `/colors`              | `?q=`, `?tag=`, `?color=RRGGBB`, `?palette=name-or-id` |
| GET    | `/colors/:id`          | Includes a `palettes` array: the reverse lookup |
| POST   | `/colors`              | Creates a standalone color |
| PATCH  | `/colors/:id`          | Shared, so this changes every palette holding it |
| DELETE | `/colors/:id`          | Refused while a palette holds it, unless `from_palettes` |
| GET    | `/lookup?q=`           | What the lookup screen answers, in one call |
| GET    | `/tags`                | Every tag in use, by collection |

A color serializes as:

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

That shape, key order included, is pinned by
`test/controllers/api/v1/contract_test.rb`. If it fails, a downstream tool
breaks: the fix is a `v2`, not an edit.

### Writing colors

`POST` and `PATCH` take a `colors` array of either references or definitions:

```json
{ "palette": { "name": "Autumn 2026", "tags": ["seasonal"],
  "colors": [ { "id": 12 },
              { "name": "moss", "source_space": "rgb", "r": 85, "g": 96, "b": 58 } ] } }
```

A definition may give `"hex"` instead of channels; a hex is RGB notation, so
`source_space` can be left out. On `PATCH` the array **replaces** the list in
the order given, so one shape covers adding, removing and reordering. Omit
the key to leave the colors alone. The write is one transaction.

### Sorting and duplicates

Both index endpoints take `?sort=` with the interface's keys: `name` (the
default), `added`, `modified`, `spectrum`, `dark`, `light`. An unrecognized
one is name, not an error. `GET /palettes/:id/colors` defaults to the
palette's own sequence, since that order is the thing being published.

`?hex=` is the name v1 published for the value filter on `/colors`, and still
answers to it.

Duplicate rules apply as they do on screen: `422` with the reason under
`errors.base`. A near-duplicate comes back with the swatch it resembles under
`similar`; resend with `"confirm_similar": true` to create it anyway.

## Conventions

Rails 8, strictly omakase: Propshaft, importmap, Hotwire, SQLite, Minitest,
fixtures. Authentication is Rails' own generator plus a token column.

The CSS is hand-written, in the spirit of the Swiss International
Typographic Style, in five files by concern: `base`, `grid`, `type`,
`components`, `transitions`. No framework, no utility classes. The typeface
is Archivo, shipped in `app/assets/fonts` as one variable Latin subset rather
than pulled from a CDN, so the app renders with nothing external reachable.
All spacing derives from custom properties in `grid.css`, and the interface is
near-monochrome so the swatches are the only color on the page.

The stylesheet says a thing once. Three type registers and two flex rules —
one row, one column — carry every repetition; a component names only how it
differs.

A button is a button and a link is a link: buttons carry a fill or a keyline
and never an underline, links keep theirs. Two signals never rest on color
alone — the current filter and the current order carry weight as well as the
accent, and a destructive action is set apart by a gap before it is colored
on hover.

Every tap target clears 24px. Search, tags, sort and size are four registers
of one block, labels in a shared column set by a single custom property, all
built from one partial. Tags on a card are the same links as the tags in the
filter bar, because they are the same thing.

Headings follow one rule: the page title is `h1`, a section is `h2`, an item's
name sits one level under whatever it belongs to.

Navigation is Turbo Drive with the View Transitions API. A swatch on the
index and the same swatch on the palette page share a `view-transition-name`,
so the browser morphs one into the other; the names key on the *membership*
rather than the color, since one color can appear in several strips and a
duplicate name silently disables the morph. `prefers-reduced-motion` turns
transitions off.

## Tests

Tests come first, and a guard is only kept if removing what it guards makes
it fail.

System tests run through `rack_test` by default, so the suite needs no
browser. That also keeps the app working with JavaScript off: Turbo Frames
fall back to full navigations, and the Stimulus preview is enhancement over a
form that already submits.

`rack_test` has no CSS, no box model and no JavaScript, though, so it will
pass a page whose layout has collapsed. The same files run in a real browser,
where the tests marked `needs_a_browser` — measured widths, the live preview,
the `:has()` panels, the clipboard — stop skipping:

```sh
SYSTEM_TEST_DRIVER=selenium bin/rails test:system
```

Each file covers one screen. Selenium Manager fetches a driver to match the
browser it finds; on a machine with both, point at them:

```sh
SYSTEM_TEST_DRIVER=selenium \
  CHROME_BINARY=/path/to/chrome CHROMEDRIVER=/path/to/chromedriver \
  bin/rails test:system
```

CI runs both: `system-test` through `rack_test`, `browser-test` in Chrome.
