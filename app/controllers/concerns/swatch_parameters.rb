# The colour-entry row shared by the new-palette form and the add-a-swatch
# form. It submits under its own `swatch` key rather than nested inside the
# palette, so the same partial works in both places.
module SwatchParameters
  extend ActiveSupport::Concern

  CHANNELS = %i[ r g b c m y k ].freeze

  included do
    helper_method :submitted_swatch
  end

  private
    # Returns nil when the row was left empty, so an untouched entry row does
    # not become a validation error on an otherwise fine palette.
    def swatch_spec
      raw = params[:swatch]
      return nil if raw.blank?

      spec = raw.permit(:name, :source_space, :tags, *CHANNELS).to_h.symbolize_keys
      return nil if spec.values_at(:name, *CHANNELS).all?(&:blank?)

      # Both fieldsets are present in the markup so the form works without
      # JavaScript; only the chosen space is sent on to the model.
      spec[:source_space] == Color::CMYK ? spec.except(:r, :g, :b) : spec.except(:c, :m, :y, :k)
    end

    def submitted_swatch
      params[:swatch] || {}
    end
end
