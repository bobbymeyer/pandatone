# A palette as an Adobe Swatch Exchange file, which is what Illustrator,
# Photoshop and InDesign read. The format is undocumented by Adobe and
# big-endian throughout:
#
#   "ASEF", uint16 major, uint16 minor, uint32 block count
#   each block: uint16 type, uint32 length, then that many bytes
#
# There is no color science here either. A color goes out in the space it was
# authored in, with its channels scaled to 0..1, because that is the record
# this app keeps — flattening a CMYK build to RGB on the way out would throw
# away the one thing the row knows that its hex does not.
module Pandatone
  class AseDocument
    SIGNATURE = "ASEF"
    VERSION = [ 1, 0 ].freeze

    GROUP_START = 0xC001
    GROUP_END = 0xC002
    COLOR = 0x0001

    # Global and spot are print production concepts this app does not model, so
    # every swatch goes out as an ordinary one.
    NORMAL = 2

    MODELS = { Color::RGB => "RGB ", Color::CMYK => "CMYK" }.freeze

    def initialize(palette)
      @palette = palette
    end

    def to_s
      header + blocks.join
    end

    private
      attr_reader :palette

      def header
        SIGNATURE.b + [ *VERSION, blocks.size ].pack("n2N")
      end

      def blocks
        @blocks ||= [
          block(GROUP_START, name(palette.name)),
          *palette.swatches.map { |color| block(COLOR, swatch(color)) },
          block(GROUP_END, "".b)
        ]
      end

      def block(type, body)
        [ type, body.bytesize ].pack("nN") + body
      end

      def swatch(color)
        name(color.name) + MODELS.fetch(color.source_space).b +
          channels(color).pack("g*") + [ NORMAL ].pack("n")
      end

      # Every channel on 0..1: RGB is stored on 0..255 and CMYK on 0..100.
      def channels(color)
        if color.rgb_source?
          color.rgb.values.map { |value| value / 255.0 }
        else
          color.cmyk.values.map { |value| value / 100.0 }
        end
      end

      # UTF-16BE and null terminated, with a length in code units that counts
      # the terminator. That last part is the whole of what makes ASE files
      # written by other people fail to open.
      def name(text)
        encoded = text.to_s.encode("UTF-16BE").b + "\x00\x00".b

        [ encoded.bytesize / 2 ].pack("n") + encoded
      end
  end
end
