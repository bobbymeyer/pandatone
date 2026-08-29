# A colour is a first-class record, not a child of a palette. One brand blue
# shared across ten seasonal palettes is one row here, which is what makes the
# reverse lookup ("which palettes contain this swatch") answerable.
class Color < ApplicationRecord
  include Taggable
  include NameSearchable
  include Sortable

  RGB = "rgb".freeze
  CMYK = "cmyk".freeze
  SOURCE_SPACES = [ RGB, CMYK ].freeze

  # Below this redmean distance two swatches are near enough that having both
  # is more likely a mistake than a decision: #FAFAF8 against #FFFFFF scores
  # 17, a red mistyped as #E01020 instead of #E30613 scores 28. Two greys
  # twenty steps apart score 60 and stay two swatches. The line is a judgement
  # about a library, not a perceptual constant, which is why it warns rather
  # than refuses.
  SIMILARITY_THRESHOLD = 32

  # Below this much chroma there is not enough hue to place on the spectrum,
  # so the colour belongs on the black-to-white axis instead. It clears the
  # off-whites and the warm greys without catching a muted olive.
  NEUTRAL_CHROMA = 24

  # Half of 255: which end of the black-to-white axis a neutral belongs on.
  NEUTRAL_MIDPOINT = 127.5

  # A wheel has no beginning, so a linear list has to cut it somewhere, and
  # wherever the cut falls two neighbouring colours end up at opposite ends.
  # Cutting at red would do it between #FF0010 and #FF0000 — putting a red
  # that leans a few degrees blue, like #E30613 at 356.5, after the violets.
  # The gap between magenta and red is the emptiest place to break, so the
  # cut goes there and every red stays with the reds.
  SPECTRUM_ORIGIN = 345

  has_many :palette_colors, dependent: :destroy
  has_many :palettes, through: :palette_colors

  before_validation :derive_companion_space

  validates :name, presence: true
  validates :source_space, inclusion: { in: SOURCE_SPACES }
  # Only the space being authored in is validated. The other one is derived,
  # so it is correct by construction when the source is, and unset when the
  # source is not — where reporting it as well would bury the one mistake
  # under a dozen complaints about channels nobody typed in.
  # allow_nil keeps a blank field to a single "can't be blank" rather than
  # that plus "is not a number".
  with_options if: :rgb_source? do
    validates :r, :g, :b, presence: true, numericality: {
      only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 255, allow_nil: true
    }
  end

  with_options if: :cmyk_source? do
    validates :c, :m, :y, :k, presence: true, numericality: {
      greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true
    }
  end
  validate :assigned_hex_must_be_readable
  validate :must_not_duplicate_a_swatch

  scope :by_hex, ->(hex) {
    rgb = ColorSpace.parse_hex(hex)
    next none if rgb.nil?

    where(rgb)
  }

  scope :in_palette, ->(key) {
    where(id: PaletteColor.where(palette_id: Palette.friendly(key).select(:id)).select(:color_id))
  }

  # The nearest swatch already on file that this one is close enough to be a
  # duplicate of, or nil. Exact matches are a validation, not a warning, so by
  # the time this is consulted the answer is always a genuinely distinct
  # colour that merely looks the same.
  def self.similar_to(color)
    return nil unless [ color.r, color.g, color.b ].all?(Integer)

    scope = near(color)
    scope = scope.where.not(id: color.id) if color.persisted?

    nearest, distance = closest_in(scope, color.rgb)
    nearest if distance && distance <= SIMILARITY_THRESHOLD
  end

  # The closest colour on file to a value, however far off it is. This is what
  # the lookup answers with when the library holds nothing matching exactly:
  # "we do not have that, but we have this". No threshold, because nearest has
  # to mean nearest, and no bounding box for the same reason — one query over
  # four integer columns reads the whole library.
  def self.nearest_to(rgb)
    closest_in(all, rgb).first
  end

  def self.closest_in(scope, rgb)
    id, distance = scope.pluck(:id, :r, :g, :b)
      .map { |row| [ row.first, ColorSpace.distance(rgb, { r: row[1], g: row[2], b: row[3] }) ] }
      .min_by(&:last)

    id ? [ find(id), distance ] : [ nil, nil ]
  end
  private_class_method :closest_in

  # A bounding box, so the search is an indexed range scan over a handful of
  # rows rather than a walk of the whole library. Every weight in the distance
  # is at least 2, and green's is exactly 4, so nothing inside the threshold
  # can fall outside this box.
  scope :near, ->(color) {
    reach = SIMILARITY_THRESHOLD / Math.sqrt(2)

    where(r: (color.r - reach)..(color.r + reach),
          g: (color.g - SIMILARITY_THRESHOLD / 2.0)..(color.g + SIMILARITY_THRESHOLD / 2.0),
          b: (color.b - reach)..(color.b + reach))
  }

  def luma
    ColorSpace.luma(r, g, b)
  end

  def hue
    ColorSpace.hue(r, g, b)
  end

  def chroma
    ColorSpace.chroma(r, g, b)
  end

  # A colour with too little hue to place on the spectrum.
  def neutral?
    chroma < NEUTRAL_CHROMA
  end

  # Black, then ROYGBIV, then white: the neutrals split to the two ends of
  # the list by which half of the black-to-white axis they sit on, and
  # everything with a hue runs between them in spectral order.
  def spectrum_position
    return [ 0, luma ] if neutral? && luma < NEUTRAL_MIDPOINT
    return [ 2, luma ] if neutral?

    [ 1, (hue - SPECTRUM_ORIGIN) % 360 ]
  end

  def dark_position
    luma
  end

  def light_position
    -luma
  end

  def hex
    ColorSpace.to_hex(r, g, b)
  end

  # hex is derived for reading, but it is also an input path: a hex field and
  # the system colour picker both hand back a hex string, and both are RGB
  # sources. Assigning it sets the RGB channels; nothing stores the string.
  def hex=(value)
    @assigned_hex = value
    rgb = ColorSpace.parse_hex(value)

    assign_attributes(rgb) if rgb
  end

  def rgb
    { r: r, g: g, b: b }
  end

  # Floats, not BigDecimal: this is what goes over the wire, and a BigDecimal
  # would serialise as a quoted string.
  def cmyk
    { c: c.to_f, m: m.to_f, y: y.to_f, k: k.to_f }
  end

  def rgb_source?
    source_space == RGB
  end

  def cmyk_source?
    source_space == CMYK
  end

  private
    # One value, one swatch. Two rows rendering the same hex are one colour
    # under two names, which breaks the reverse lookup ("which palettes contain
    # #E30613") into an arbitrary choice between them. A CMYK recipe that lands
    # on a colour already on file is held to the same line: on screen, and in
    # this library, it is that colour.
    def must_not_duplicate_a_swatch
      return unless [ r, g, b ].all?(Integer)

      scope = Color.where(r: r, g: g, b: b)
      scope = scope.where.not(id: id) if persisted?
      twin = scope.first
      return if twin.nil?

      errors.add(:base, %(#{hex} is already in the library as "#{twin.name}"))
    end

    def assigned_hex_must_be_readable
      return if @assigned_hex.blank? || ColorSpace.parse_hex(@assigned_hex)

      errors.add(:hex, "is not a colour we can read")
    end

    # The source space is the truth; the other one is redrawn from it on every
    # write, so the two can never drift apart.
    def derive_companion_space
      case source_space
      when RGB
        return unless [ r, g, b ].all?(Integer)

        assign_attributes(ColorSpace.rgb_to_cmyk(r, g, b))
      when CMYK
        return unless [ c, m, y, k ].all?(Numeric)

        assign_attributes(ColorSpace.cmyk_to_rgb(c, m, y, k))
      end
    end
end
