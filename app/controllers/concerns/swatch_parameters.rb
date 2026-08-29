# The color-entry row shared by the new-palette form and the add-a-swatch
# form. It submits under its own `swatch` key rather than nested inside the
# palette, so the same partial works in both places.
#
# The row offers four ways in — RGB, CMYK, a hex field and the system color
# picker — but a Color only knows two spaces. Hex and the picker are both ways
# of writing an RGB color, so they resolve to an rgb source and hand the
# string to Color#hex=. The input mode is a property of the form, not of the
# color, and nothing stores it.
module SwatchParameters
  extend ActiveSupport::Concern

  CHANNELS = %i[ r g b c m y k ].freeze
  INPUT_MODES = %w[ rgb cmyk hex picker ].freeze

  included do
    helper_method :submitted_swatch, :swatch_input_mode
  end

  private
    # The swatch already on file that this one is close enough to be a
    # duplicate of, or nil. A near-duplicate is a judgment call, not a
    # mistake, so it is put as a question rather than refused outright — but
    # it is put before the row is written, because a library nobody trusts to
    # be free of near-identical swatches is a library nobody looks in.
    #
    # The confirmation carries the value it was given for, so changing the
    # color after seeing the warning asks again about the new one instead of
    # waving through something nobody looked at. An exact duplicate is a
    # validation, not a warning, and is left to speak for itself.
    def similar_swatch_for(color)
      return nil if color.hex.present? && params[:confirm_similar] == color.hex
      return nil unless color.valid?

      Color.similar_to(color)
    end

    # Returns nil when the row was left empty, so an untouched entry row does
    # not become a validation error on an otherwise fine palette. Only the
    # chosen mode's own fields count toward that: the color picker always
    # posts a value, so asking whether every field is blank would make an
    # untouched form look filled in.
    def swatch_spec
      return nil if params[:swatch].blank? || swatch_blank?

      swatch_attributes
    end

    # Editing always writes what the row says; only adding a swatch treats an
    # untouched row as "no swatch wanted".
    def swatch_attributes
      {
        name: permitted_swatch[:name],
        tags: permitted_swatch[:tags],
        source_space: swatch_input_mode == Color::CMYK ? Color::CMYK : Color::RGB
      }.merge(swatch_values)
    end

    def swatch_blank?
      permitted_swatch[:name].blank? && swatch_values.values.all?(&:blank?)
    end

    def swatch_values
      case swatch_input_mode
      when Color::CMYK then permitted_swatch.slice(:c, :m, :y, :k).to_h.symbolize_keys
      when "hex"       then { hex: permitted_swatch[:hex] }
      when "picker"    then { hex: permitted_swatch[:picker] }
      else                  permitted_swatch.slice(:r, :g, :b).to_h.symbolize_keys
      end
    end

    # What was just submitted wins, so a validation error keeps you in the
    # panel you were using; otherwise a color being edited opens in the space
    # it was authored in.
    def swatch_input_mode(color = nil)
      mode = params.dig(:swatch, :input_mode)
      return mode if INPUT_MODES.include?(mode)

      source = color&.source_space
      INPUT_MODES.include?(source) ? source : Color::RGB
    end

    def permitted_swatch
      @permitted_swatch ||= (params[:swatch] || ActionController::Parameters.new).permit(:name, :tags, :input_mode, :hex, :picker, *CHANNELS)
    end

    def submitted_swatch
      params[:swatch] || {}
    end
end
