# Writes a palette and, optionally, its whole ordered colour list in one
# transaction.
#
# Replacing the list rather than diffing it means a single shape of request
# covers adding, removing and reordering swatches, and a half-applied change
# is impossible: either the palette ends up exactly as described or nothing
# moves. Colours removed from a palette are left in the library, since they
# may sit in other palettes.
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
    end

    true
  rescue Invalid
    false
  end

  private
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

    # An entry is either a reference to a colour already in the library
    # ({ "id": 12 }) or a full definition to create. References are how one
    # brand blue ends up in ten palettes as a single row.
    def resolve(spec)
      spec = spec.to_h.symbolize_keys

      if spec[:id].present?
        existing = Color.find_by(id: spec[:id])
        @palette.errors.add(:colors, "reference #{spec[:id]} does not exist") if existing.nil?
        existing
      else
        color = Color.new(spec.except(:id))
        add_errors_from(color) unless color.save
        color
      end
    end

    def add_errors_from(record)
      record.errors.full_messages.each { |message| @palette.errors.add(:colors, message) }
    end
end
