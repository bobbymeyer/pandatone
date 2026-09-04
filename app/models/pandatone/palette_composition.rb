# Writes a palette and, optionally, its whole ordered color list in one
# transaction.
#
# Replacing the list rather than diffing it means a single shape of request
# covers adding, removing and reordering swatches, and a half-applied change
# is impossible: either the palette ends up exactly as described or nothing
# moves. Colors removed from a palette are left in the library, since they
# may sit in other palettes.
module Pandatone
  class PaletteComposition
    Invalid = Class.new(StandardError)
    private_constant :Invalid

    # colors: replaces the whole ordered list. append: adds to the end of it.
    # The API replaces; the web forms append one swatch at a time.
    def initialize(palette, attributes:, colors: nil, append: nil)
      @palette = palette
      @attributes = attributes
      @colors = colors
      @append = append
    end

    def save
      Palette.transaction do
        @palette.assign_attributes(@attributes)
        raise Invalid unless @palette.save

        replace_colors unless @colors.nil?
        append_colors if @append.present?
        ensure_composition_is_distinct
      end

      true
    rescue Invalid
      false
    end

    private
      # A palette is the set of colors it holds; its name is a label on that
      # set, not part of it. Two palettes holding the same colors are one
      # palette filed twice, so the second is refused rather than saved and
      # left to be noticed later. Order is not part of the identity — the same
      # five colors resequenced are the same palette — and empty palettes do
      # not duplicate one another, or a second one could never be started.
      def ensure_composition_is_distinct
        color_ids = @palette.palette_colors.reload.pluck(:color_id)
        twin = palette_holding(color_ids)
        return if twin.nil?

        @palette.errors.add(:base, %("#{twin.name}" already holds exactly these colors))
        raise Invalid
      end

      def palette_holding(color_ids)
        return nil if color_ids.empty?

        # (palette_id, color_id) is unique, so a palette with this many rows, all
        # of them in this set, holds this set and nothing else.
        twin_id = PaletteColor.where.not(palette_id: @palette.id)
          .group(:palette_id)
          .having("COUNT(*) = :size AND SUM(CASE WHEN color_id IN (:ids) THEN 1 ELSE 0 END) = :size",
            size: color_ids.size, ids: color_ids)
          .pluck(:palette_id)
          .first

        Palette.find_by(id: twin_id)
      end

      def append_colors
        resolved = @append.map { |spec| resolve(spec) }
        raise Invalid if @palette.errors.any?

        attach(resolved, from: (@palette.palette_colors.maximum(:position) || -1) + 1)
      end

      def replace_colors
        # Resolve everything before touching the palette, so an invalid entry
        # anywhere in the list leaves the existing swatches untouched.
        resolved = @colors.map { |spec| resolve(spec) }
        raise Invalid if @palette.errors.any?

        @palette.palette_colors.destroy_all

        attach(resolved, from: 0)
      end

      def attach(colors, from:)
        colors.each_with_index do |color, offset|
          membership = @palette.palette_colors.create(color: color, position: from + offset)
          next if membership.persisted?

          add_errors_from(membership)
          raise Invalid
        end
      end

      # An entry is either a reference to a color already in the library
      # ({ "id": 12 }) or a full definition to create. References are how one
      # brand blue ends up in ten palettes as a single row.
      def resolve(spec)
        spec = spec.to_h.symbolize_keys

        if spec[:id].present?
          existing = Color.find_by(id: spec[:id])
          @palette.errors.add(:base, "No color with id #{spec[:id]}") if existing.nil?
          existing
        else
          color = Color.new(spec.except(:id))
          add_errors_from(color) unless color.save
          color
        end
      end

      def add_errors_from(record)
        # :base, not :colors — the palette's own full_messages would otherwise
        # prefix every one of these with the association name.
        record.errors.full_messages.each { |message| @palette.errors.add(:base, message) }
      end
  end
end
