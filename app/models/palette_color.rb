# Membership of a colour in a palette, at a position. Ordering lives here
# rather than on Color, because the same colour sits at different positions in
# different palettes.
class PaletteColor < ApplicationRecord
  belongs_to :palette
  belongs_to :color

  before_validation :assign_next_position, on: :create

  validates :position, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :color_id, uniqueness: { scope: :palette_id }

  private
    # Appending without a position puts the swatch at the end of the strip.
    def assign_next_position
      self.position ||= (palette&.palette_colors&.maximum(:position) || -1) + 1
    end
end
