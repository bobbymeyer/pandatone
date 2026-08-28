class Palette < ApplicationRecord
  include Taggable

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

  scope :containing_hex, ->(hex) {
    rgb = ColorSpace.parse_hex(hex)
    next none if rgb.nil?

    where(id: PaletteColor.where(color_id: Color.where(rgb).select(:id)).select(:palette_id))
  }

  def self.friendly_find(key)
    friendly(key).first || raise(ActiveRecord::RecordNotFound, "Couldn't find Palette matching #{key.inspect}")
  end

  private
    def strip_name
      self.name = name.strip if name.is_a?(String)
    end
end
