# A colour is a first-class record, not a child of a palette. One brand blue
# shared across ten seasonal palettes is one row here, which is what makes the
# reverse lookup ("which palettes contain this swatch") answerable.
class Color < ApplicationRecord
  include Taggable

  RGB = "rgb".freeze
  CMYK = "cmyk".freeze
  SOURCE_SPACES = [ RGB, CMYK ].freeze

  has_many :palette_colors, dependent: :destroy
  has_many :palettes, through: :palette_colors

  before_validation :derive_companion_space

  validates :name, presence: true
  validates :source_space, inclusion: { in: SOURCE_SPACES }
  validates :r, :g, :b, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 255 }
  validates :c, :m, :y, :k, presence: true,
    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  scope :by_hex, ->(hex) {
    rgb = ColorSpace.parse_hex(hex)
    next none if rgb.nil?

    where(rgb)
  }

  scope :in_palette, ->(key) {
    where(id: PaletteColor.where(palette_id: Palette.friendly(key).select(:id)).select(:color_id))
  }

  def hex
    ColorSpace.to_hex(r, g, b)
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

  private
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
