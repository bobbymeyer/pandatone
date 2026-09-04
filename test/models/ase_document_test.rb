require "test_helper"

module Pandatone
  # Adobe Swatch Exchange, big-endian throughout:
  #
  #   "ASEF", uint16 major, uint16 minor, uint32 block count
  #   each block: uint16 type, uint32 length, then that many bytes
  #     0xC001 group start: uint16 name length, UTF-16BE name, null terminated
  #     0xC002 group end:   nothing
  #     0x0001 color:       the same name, then a four byte model, then one
  #                         big-endian float per channel, then uint16 color type
  #
  # The name length counts UTF-16 code units including the terminator, which is
  # the one part of this everybody gets wrong. These tests decode what the
  # writer produced rather than comparing it to a blob, so a failure says which
  # field moved.
  class AseDocumentTest < ActiveSupport::TestCase
    test "announces itself as an ASE version 1.0 file" do
      signature, major, minor = decode(palettes(:brand)).values_at(:signature, :major, :minor)

      assert_equal "ASEF", signature
      assert_equal 1, major
      assert_equal 0, minor
    end

    test "counts every block it wrote, the group markers included" do
      file = decode(palettes(:brand))

      assert_equal file[:blocks].length, file[:count]
      assert_equal palettes(:brand).colors.size + 2, file[:count]
    end

    # The palette name is the group name, so importing it lands the swatches
    # together under the name they were exported as rather than loose.
    test "wraps the swatches in a group named for the palette" do
      blocks = decode(palettes(:brand))[:blocks]

      assert_equal 0xC001, blocks.first[:type]
      assert_equal "Brand Core", blocks.first[:name]
      assert_equal 0xC002, blocks.last[:type]
    end

    test "writes the swatches in the order the palette holds them" do
      colors = decode(palettes(:brand))[:blocks].select { |block| block[:type] == 0x0001 }

      assert_equal palettes(:brand).swatches.map(&:name), colors.map { |block| block[:name] }
    end

    # The app records which space a color was authored in, so an export that
    # flattened everything to RGB would throw away the one thing the record
    # knows that the hex does not.
    test "writes each color in the space it was authored in" do
      palette = Palette.create!(name: "Both Spaces")
      palette.palette_colors.create!(color: colors(:signal_red), position: 0)
      palette.palette_colors.create!(color: colors(:process_cyan), position: 1)

      models = decode(palette)[:blocks].select { |b| b[:type] == 0x0001 }.map { |b| b[:model] }

      assert_equal [ "RGB ", "CMYK" ], models
    end

    test "writes RGB as three channels on nought to one" do
      block = color_block(palettes(:brand), "signal-red")

      assert_equal "RGB ", block[:model]
      # Rounded on both sides: the file holds single precision floats, so a
      # comparison against a double would fail on the format being the format.
      assert_equal [ 227 / 255.0, 6 / 255.0, 19 / 255.0 ].map { |v| v.round(6) },
        block[:values].map { |v| v.round(6) },
        "RGB channels are 0..255 in the record and 0..1 in the file"
    end

    test "writes CMYK as four inks on nought to one" do
      palette = Palette.create!(name: "Process")
      palette.palette_colors.create!(color: colors(:process_cyan), position: 0)

      block = color_block(palette, "process-cyan")

      assert_equal "CMYK", block[:model]
      assert_equal [ 1.0, 0.0, 0.0, 0.0 ], block[:values].map { |v| v.round(6) },
        "inks are 0..100 in the record and 0..1 in the file"
    end

    # 2 for the name length, the name itself, 4 for the model, 4 per channel,
    # and 2 for the color type.
    test "gives every block a length that matches the bytes after it" do
      decode(palettes(:brand))[:blocks].each do |block|
        assert_equal block[:length], block[:body].bytesize,
          "a #{block[:type].to_s(16)} block declared a length it did not write"
      end
    end

    test "marks colors normal rather than global or spot" do
      assert_equal 2, color_block(palettes(:brand), "signal-red")[:color_type]
    end

    # A name outside Latin-1 is why the name is UTF-16 in the first place.
    test "carries a name that needs more than one byte a character" do
      palette = Palette.create!(name: "Paletteński")
      color = Color.create!(name: "żółty", source_space: Color::RGB, r: 250, g: 200, b: 20)
      palette.palette_colors.create!(color: color, position: 0)

      file = decode(palette)

      assert_equal "Paletteński", file[:blocks].first[:name]
      assert_equal "żółty", file[:blocks][1][:name]
    end

    test "writes a palette holding nothing as an empty group" do
      file = decode(palettes(:empty))

      assert_equal 2, file[:count]
      assert_equal [ 0xC001, 0xC002 ], file[:blocks].map { |block| block[:type] }
    end

    private
      def decode(palette)
        bytes = AseDocument.new(palette).to_s
        signature = bytes[0, 4]
        major, minor, count = bytes[4, 8].unpack("n2N")

        { signature: signature, major: major, minor: minor, count: count,
          blocks: decode_blocks(bytes[12..]) }
      end

      def decode_blocks(bytes)
        blocks = []

        until bytes.empty?
          type, length = bytes[0, 6].unpack("nN")
          body = bytes[6, length]
          blocks << decode_block(type, length, body)
          bytes = bytes[(6 + length)..]
        end

        blocks
      end

      def decode_block(type, length, body)
        block = { type: type, length: length, body: body }
        return block if body.empty?

        units = body[0, 2].unpack1("n")
        block[:name] = body[2, (units - 1) * 2].force_encoding("UTF-16BE").encode("UTF-8")

        rest = body[(2 + units * 2)..]
        return block if rest.nil? || rest.empty?

        block[:model] = rest[0, 4]
        channels = { "RGB " => 3, "CMYK" => 4, "LAB " => 3, "Gray" => 1 }.fetch(block[:model])
        block[:values] = rest[4, channels * 4].unpack("g#{channels}")
        block[:color_type] = rest[4 + channels * 4, 2].unpack1("n")
        block
      end

      def color_block(palette, name)
        decode(palette)[:blocks].find { |block| block[:type] == 0x0001 && block[:name] == name }
      end
  end
end
