# A color is a first-class record, not a child of a palette. One brand blue
# shared across ten seasonal palettes is one row here, which is what makes the
# reverse lookup ("which palettes contain this swatch") answerable.
module Pandatone
  class Color < ApplicationRecord
    include Taggable
    include NameSearchable
    include Sortable
    include ColorGeometry

    RGB = "rgb".freeze
    CMYK = "cmyk".freeze
    SOURCE_SPACES = [ RGB, CMYK ].freeze

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

    # Any way a color might be written down: a hex, an RGB triple or a CMYK
    # build. Every color stores both spaces, so matching on the RGB all three
    # resolve to is what lets a search in one space find a color authored in
    # the other.
    scope :by_value, ->(input) {
      rgb = ColorSpace.parse(input)
      next none if rgb.nil?

      where(rgb)
    }

    scope :in_palette, ->(key) {
      where(id: PaletteColor.where(palette_id: Palette.friendly(key).select(:id)).select(:color_id))
    }

    def hex
      ColorSpace.to_hex(r, g, b)
    end

    # hex is derived for reading, but it is also an input path: a hex field and
    # the system color picker both hand back a hex string, and both are RGB
    # sources. Assigning it sets the RGB channels; nothing stores the string.
    #
    # A hex is an RGB notation, so writing one authors the color in RGB unless
    # the caller has already said otherwise. That is what lets a client hand
    # over the hex it has without also spelling out a space it did not choose.
    def hex=(value)
      @assigned_hex = value
      rgb = ColorSpace.parse_hex(value)
      return if rgb.nil?

      self.source_space ||= RGB
      assign_attributes(rgb)
    end

    def rgb
      { r: r, g: g, b: b }
    end

    # Floats, not BigDecimal: this is what goes over the wire, and a BigDecimal
    # would serialize as a quoted string.
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
      # One value, one swatch. Two rows rendering the same hex are one color
      # under two names, which breaks the reverse lookup ("which palettes contain
      # #E30613") into an arbitrary choice between them. A CMYK recipe that lands
      # on a color already on file is held to the same line: on screen, and in
      # this library, it is that color.
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

        errors.add(:hex, "is not a color we can read")
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
end
