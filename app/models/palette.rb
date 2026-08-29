class Palette < ApplicationRecord
  include Taggable
  include NameSearchable
  include Sortable

  has_many :palette_colors, -> { order(:position) }, dependent: :destroy, inverse_of: :palette
  has_many :colors, through: :palette_colors

  before_validation :strip_name

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # Palettes are addressable by name as well as id, because a consuming tool
  # asking for "Brand Core" should not have to look an id up first.
  scope :friendly, ->(key) {
    key = key.to_s.strip
    next none if key.blank?

    where("palettes.id = :id OR LOWER(palettes.name) = :name",
      id: Integer(key, exception: false), name: key.downcase)
  }

  # Reads the same three notations the color scope does, for the same reason.
  scope :containing, ->(input) {
    rgb = ColorSpace.parse(input)
    next none if rgb.nil?

    where(id: PaletteColor.where(color_id: Color.where(rgb).select(:id)).select(:palette_id))
  }

  # The swatches in the order the strip shows them. Read through the join
  # rows rather than through `colors`, so the index's own preload covers it
  # and sorting a page of palettes stays one query.
  def swatches
    palette_colors.map(&:color)
  end

  # A palette is dark or light as a whole rather than at its first swatch, so
  # this averages. Averaging is honest for a scalar like luma in a way it
  # would never be for a hue, where the mean of red and violet is green.
  def luma
    swatches.sum(&:luma) / swatches.size if swatches.any?
  end

  # Which is why the color sort reads the swatch the strip leads with: the
  # one anchoring the palette, and the one you see first on every screen that
  # shows it. A palette holding nothing has no color to sort by, so it goes
  # last rather than pretending to be black.
  def spectrum_position
    swatches.any? ? [ 0, *swatches.first.spectrum_position ] : [ 1 ]
  end

  def dark_position
    swatches.any? ? [ 0, luma ] : [ 1 ]
  end

  def light_position
    swatches.any? ? [ 0, -luma ] : [ 1 ]
  end

  def self.friendly_find(key)
    friendly(key).first || raise(ActiveRecord::RecordNotFound, "Couldn't find Palette matching #{key.inspect}")
  end

  private
    def strip_name
      self.name = name.strip if name.is_a?(String)
    end
end
