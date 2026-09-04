# A palette in the two formats a design tool reads. Shared by the interface,
# where it is a link you click, and by the API, where it is a file a script
# fetches — one implementation, so the two cannot drift.
module Pandatone
  module PaletteExports
    extend ActiveSupport::Concern

    # ActionController::API leaves MimeResponds out, so the API controller has no
    # respond_to until something puts it back. Bringing it in here rather than in
    # the base controller keeps it with the one feature that asks for it.
    included do
      include ActionController::MimeResponds
    end

    FORMATS = {
      ase: { document: AseDocument, type: "application/x-adobe-ase" },
      css: { document: CssVariables, type: "text/css" }
    }.freeze

    private
      def send_palette(palette, format)
        spec = FORMATS.fetch(format)

        send_data spec[:document].new(palette).to_s,
          type: spec[:type],
          filename: "#{palette.name.parameterize}.#{format}",
          disposition: :attachment
      end
  end
end
