# Deletes a colour from the library, with the two guards that make deletion
# safe to offer at all.
#
# A colour is shared, so deleting one held by palettes silently rewrites every
# one of them — a much larger act than a button reading "delete colour"
# suggests. That is refused until it is asked for in those terms, and the
# refusal names the palettes so the choice is an informed one.
#
# The second guard is the palette-uniqueness rule, which cannot be true only
# on the way in: stripping a colour out of a palette can land it on exactly
# the colours another palette holds, and a cascade that quietly does so breaks
# the rule as thoroughly as saving a duplicate would.
class ColorRemoval
  def initialize(color, from_palettes: false)
    @color = color
    @from_palettes = from_palettes
  end

  def destroy
    return false unless permitted? && leaves_palettes_distinct?

    Color.transaction do
      @color.palette_colors.map(&:palette).uniq.each { |palette| strip(palette) }
      @color.destroy!
    end

    true
  end

  private
    def permitted?
      holders = @color.palettes.reorder(:name)
      return true if @from_palettes || holders.empty?

      @color.errors.add(:base, "#{@color.name} is in #{holders.map(&:name).to_sentence}. " \
        "Delete it from those palettes too if you mean to remove it.")
      false
    end

    def leaves_palettes_distinct?
      twins = colliding_palettes
      return true if twins.nil?

      @color.errors.add(:base,
        %(Deleting this would leave #{twins.map { |name| %("#{name}") }.to_sentence} ) +
        "holding exactly the same colours.")
      false
    end

    # Compares what every palette would hold afterwards, rather than only the
    # ones this colour touches: two palettes it strips can just as easily
    # collide with each other as with a third it never appears in.
    def colliding_palettes
      Palette.includes(:palette_colors).map { |palette|
        [ palette, palette.palette_colors.map(&:color_id) - [ @color.id ] ]
      }.reject { |_, color_ids| color_ids.empty? }
        .group_by { |_, color_ids| color_ids.sort }
        .values.find { |group| group.size > 1 }
        &.map { |palette, _| palette.name }&.sort
    end

    # Renumbers from zero rather than leaving the gap the removed swatch left.
    def strip(palette)
      remaining = palette.palette_colors.reject { |membership| membership.color_id == @color.id }

      remaining.each_with_index do |membership, position|
        membership.update!(position: position) unless membership.position == position
      end
    end
end
