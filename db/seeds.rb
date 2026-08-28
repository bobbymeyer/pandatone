# A small but real library, so the app demos meaningfully and manual QA has
# something to look at. Idempotent: run it as often as you like.
#
# Note that signal-red and ink-black each sit in two palettes as a single
# Color row. That sharing is the point of the join table, and it is what makes
# "which palettes contain #E30613" a question worth asking.

RGB_COLORS = [
  { name: "signal-red",    r: 227, g: 6,   b: 19,  tags: %w[ brand primary ] },
  { name: "ink-black",     r: 17,  g: 17,  b: 17,  tags: %w[ brand neutral ] },
  { name: "paper-white",   r: 250, g: 249, b: 247, tags: %w[ brand neutral ] },
  { name: "grid-grey",     r: 111, g: 111, b: 106, tags: %w[ brand neutral ] },
  { name: "autumn-ochre",  r: 196, g: 132, b: 44,  tags: %w[ seasonal warm ] },
  { name: "burnt-sienna",  r: 140, g: 59,  b: 30,  tags: %w[ seasonal warm ] },
  { name: "moss",          r: 85,  g: 96,  b: 58,  tags: %w[ seasonal ] },
  { name: "frost",         r: 200, g: 220, b: 255, tags: %w[ seasonal cool ] },
  { name: "deep-indigo",   r: 43,  g: 74,  b: 138, tags: %w[ cool ] }
].freeze

# Authored in CMYK, because that is how process inks are specified. Their RGB
# is the derived approximation, not the other way round.
CMYK_COLORS = [
  { name: "process-cyan",    c: 100, m: 0,   y: 0,   k: 0,   tags: %w[ print process ] },
  { name: "process-magenta", c: 0,   m: 100, y: 0,   k: 0,   tags: %w[ print process ] },
  { name: "process-yellow",  c: 0,   m: 0,   y: 100, k: 0,   tags: %w[ print process ] },
  { name: "process-key",     c: 0,   m: 0,   y: 0,   k: 100, tags: %w[ print process ] }
].freeze

PALETTES = {
  "Brand Core"  => { tags: %w[ brand active ],    colors: %w[ signal-red ink-black paper-white grid-grey ] },
  "Autumn 2026" => { tags: %w[ seasonal active ], colors: %w[ autumn-ochre burnt-sienna moss signal-red ] },
  "Winter 2027" => { tags: %w[ seasonal ],        colors: %w[ frost deep-indigo ink-black ] },
  "Press Check" => { tags: %w[ print ],           colors: %w[ process-cyan process-magenta process-yellow process-key ] }
}.freeze

colors = {}

RGB_COLORS.each do |attributes|
  colors[attributes[:name]] = Color.find_or_initialize_by(name: attributes[:name]).tap do |color|
    color.update!(attributes.merge(source_space: Color::RGB))
  end
end

CMYK_COLORS.each do |attributes|
  colors[attributes[:name]] = Color.find_or_initialize_by(name: attributes[:name]).tap do |color|
    color.update!(attributes.merge(source_space: Color::CMYK))
  end
end

PALETTES.each do |name, definition|
  palette = Palette.find_or_initialize_by(name: name)

  PaletteComposition.new(
    palette,
    attributes: { tags: definition[:tags] },
    colors: definition[:colors].map { |color_name| { id: colors.fetch(color_name).id } }
  ).save || abort("Could not seed #{name}: #{palette.errors.full_messages.to_sentence}")
end

puts "Seeded #{Palette.count} palettes and #{Color.count} colours."
