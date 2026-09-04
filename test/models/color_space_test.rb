require "test_helper"

module Pandatone
  # ColorSpace is the single place device RGB <-> CMYK conversion happens.
  # The conversion is naive and device-dependent by design: no ICC profiles,
  # no gamut mapping. These tests pin the formulas to known value pairs so a
  # refactor cannot quietly change what gets written to the database.
  class ColorSpaceTest < ActiveSupport::TestCase
    # --- RGB -> CMYK -------------------------------------------------------

    test "converts white to no ink" do
      assert_equal({ c: 0.0, m: 0.0, y: 0.0, k: 0.0 }, ColorSpace.rgb_to_cmyk(255, 255, 255))
    end

    test "converts black to pure key" do
      assert_equal({ c: 0.0, m: 0.0, y: 0.0, k: 100.0 }, ColorSpace.rgb_to_cmyk(0, 0, 0))
    end

    test "converts the additive primaries to their subtractive complements" do
      assert_equal({ c: 0.0, m: 100.0, y: 100.0, k: 0.0 }, ColorSpace.rgb_to_cmyk(255, 0, 0))
      assert_equal({ c: 100.0, m: 0.0, y: 100.0, k: 0.0 }, ColorSpace.rgb_to_cmyk(0, 255, 0))
      assert_equal({ c: 100.0, m: 100.0, y: 0.0, k: 0.0 }, ColorSpace.rgb_to_cmyk(0, 0, 255))
    end

    test "converts the subtractive primaries" do
      assert_equal({ c: 100.0, m: 0.0, y: 0.0, k: 0.0 }, ColorSpace.rgb_to_cmyk(0, 255, 255))
      assert_equal({ c: 0.0, m: 100.0, y: 0.0, k: 0.0 }, ColorSpace.rgb_to_cmyk(255, 0, 255))
      assert_equal({ c: 0.0, m: 0.0, y: 100.0, k: 0.0 }, ColorSpace.rgb_to_cmyk(255, 255, 0))
    end

    test "converts neutral gray to key only" do
      assert_equal({ c: 0.0, m: 0.0, y: 0.0, k: 49.8 }, ColorSpace.rgb_to_cmyk(128, 128, 128))
    end

    test "converts a real brand color" do
      # signal-red, #E30613
      assert_equal({ c: 0.0, m: 97.4, y: 91.6, k: 11.0 }, ColorSpace.rgb_to_cmyk(227, 6, 19))
    end

    test "rounds cmyk channels to one decimal place" do
      ColorSpace.rgb_to_cmyk(17, 93, 200).each_value do |v|
        assert_equal v.round(1), v, "expected #{v} to already be rounded to 1dp"
      end
    end

    # --- CMYK -> RGB -------------------------------------------------------

    test "converts no ink to white" do
      assert_equal({ r: 255, g: 255, b: 255 }, ColorSpace.cmyk_to_rgb(0, 0, 0, 0))
    end

    test "converts pure key to black" do
      assert_equal({ r: 0, g: 0, b: 0 }, ColorSpace.cmyk_to_rgb(0, 0, 0, 100))
    end

    test "converts subtractive primaries back to additive" do
      assert_equal({ r: 255, g: 0, b: 0 }, ColorSpace.cmyk_to_rgb(0, 100, 100, 0))
      assert_equal({ r: 0, g: 255, b: 255 }, ColorSpace.cmyk_to_rgb(100, 0, 0, 0))
    end

    test "applies key as a linear multiplier" do
      assert_equal({ r: 128, g: 128, b: 128 }, ColorSpace.cmyk_to_rgb(0, 0, 0, 50))
    end

    test "returns integer rgb channels" do
      ColorSpace.cmyk_to_rgb(12.5, 40.1, 88.8, 3.2).each_value do |v|
        assert_kind_of Integer, v
      end
    end

    test "accepts BigDecimal cmyk channels as read back from the database" do
      cmyk = { c: BigDecimal("0.0"), m: BigDecimal("97.4"), y: BigDecimal("91.6"), k: BigDecimal("11.0") }
      assert_equal({ r: 227, g: 6, b: 19 }, ColorSpace.cmyk_to_rgb(cmyk[:c], cmyk[:m], cmyk[:y], cmyk[:k]))
    end

    # --- Bounds ------------------------------------------------------------

    test "clamps out of range rgb input" do
      assert_equal ColorSpace.rgb_to_cmyk(255, 0, 128), ColorSpace.rgb_to_cmyk(300, -5, 128)
    end

    test "clamps out of range cmyk input" do
      assert_equal ColorSpace.cmyk_to_rgb(100, 0, 50, 0), ColorSpace.cmyk_to_rgb(140, -12, 50, 0)
    end

    test "never emits an out of range channel" do
      [ [ 0, 0, 0 ], [ 255, 255, 255 ], [ 1, 2, 3 ], [ 254, 1, 128 ] ].each do |rgb|
        ColorSpace.rgb_to_cmyk(*rgb).each_value { |v| assert_includes 0.0..100.0, v }
      end
      [ [ 0, 0, 0, 0 ], [ 100, 100, 100, 100 ], [ 3.3, 99.9, 0.1, 50 ] ].each do |cmyk|
        ColorSpace.cmyk_to_rgb(*cmyk).each_value { |v| assert_includes 0..255, v }
      end
    end

    # --- Round trips -------------------------------------------------------
    #
    # RGB is the lossless direction: every one of the 16,777,216 sRGB triples
    # survives a trip through 1-decimal CMYK and back unchanged. The sweep
    # below samples that space; the exhaustive check lives in the repo history.
    test "rgb survives a round trip through cmyk unchanged" do
      0.step(255, 17) do |r|
        0.step(255, 17) do |g|
          0.step(255, 17) do |b|
            cmyk = ColorSpace.rgb_to_cmyk(r, g, b)
            back = ColorSpace.cmyk_to_rgb(cmyk[:c], cmyk[:m], cmyk[:y], cmyk[:k])
            assert_equal({ r: r, g: g, b: b }, back, "lost rgb(#{r}, #{g}, #{b}) via #{cmyk.inspect}")
          end
        end
      end
    end

    # CMYK is the lossy direction, and this is the documented reason
    # source_space exists: many CMYK mixes collapse onto one RGB triple, so a
    # CMYK-sourced color must keep its own values as the source of truth
    # rather than being re-derived from RGB.
    test "cmyk does not survive a round trip through rgb" do
      rgb = ColorSpace.cmyk_to_rgb(50, 50, 50, 50)
      assert_equal({ r: 64, g: 64, b: 64 }, rgb)

      back = ColorSpace.rgb_to_cmyk(rgb[:r], rgb[:g], rgb[:b])
      assert_equal({ c: 0.0, m: 0.0, y: 0.0, k: 74.9 }, back)
      refute_equal({ c: 50.0, m: 50.0, y: 50.0, k: 50.0 }, back)
    end

    test "distinct cmyk mixes can collapse onto the same rgb triple" do
      assert_equal ColorSpace.cmyk_to_rgb(0, 0, 0, 100), ColorSpace.cmyk_to_rgb(100, 100, 100, 100)
    end

    # --- Hex ---------------------------------------------------------------

    test "formats rgb as uppercase hex" do
      assert_equal "#E30613", ColorSpace.to_hex(227, 6, 19)
      assert_equal "#000000", ColorSpace.to_hex(0, 0, 0)
      assert_equal "#FFFFFF", ColorSpace.to_hex(255, 255, 255)
    end

    test "pads single digit channels" do
      assert_equal "#010203", ColorSpace.to_hex(1, 2, 3)
    end

    test "parses hex with or without a leading hash" do
      expected = { r: 227, g: 6, b: 19 }
      assert_equal expected, ColorSpace.parse_hex("#E30613")
      assert_equal expected, ColorSpace.parse_hex("E30613")
      assert_equal expected, ColorSpace.parse_hex("e30613")
      assert_equal expected, ColorSpace.parse_hex("  #e30613  ")
    end

    test "parses three digit shorthand hex" do
      assert_equal({ r: 255, g: 204, b: 0 }, ColorSpace.parse_hex("#FC0"))
    end

    test "returns nil for unparseable hex" do
      [ nil, "", "  ", "#12345", "ZZZZZZ", "#1234567", "rgb(1,2,3)" ].each do |bad|
        assert_nil ColorSpace.parse_hex(bad), "expected #{bad.inspect} to be unparseable"
      end
    end

    test "normalizes hex to a canonical string" do
      assert_equal "#E30613", ColorSpace.normalize_hex("e30613")
      assert_equal "#FFCC00", ColorSpace.normalize_hex("fc0")
      assert_nil ColorSpace.normalize_hex("nope")
    end

    # --- Freeform parsing --------------------------------------------------
    #
    # What someone pastes into the lookup field: a hex, an RGB triple, or
    # whatever their design tool put on the clipboard.

    test "parses a pasted hex" do
      assert_equal({ r: 227, g: 6, b: 19 }, ColorSpace.parse("#E30613"))
      assert_equal({ r: 227, g: 6, b: 19 }, ColorSpace.parse("e30613"))
      assert_equal({ r: 255, g: 204, b: 0 }, ColorSpace.parse("#fc0"))
    end

    test "parses a pasted rgb triple however it is punctuated" do
      expected = { r: 227, g: 6, b: 19 }

      assert_equal expected, ColorSpace.parse("227, 6, 19")
      assert_equal expected, ColorSpace.parse("227 6 19")
      assert_equal expected, ColorSpace.parse("rgb(227, 6, 19)")
      assert_equal expected, ColorSpace.parse("  227,6,19  ")
    end

    test "reads six digits as hex rather than as a triple" do
      assert_equal({ r: 18, g: 52, b: 86 }, ColorSpace.parse("123456"))
    end

    test "rejects a triple with a channel out of range" do
      assert_nil ColorSpace.parse("300, 0, 0")
      assert_nil ColorSpace.parse("-1, 0, 0")
    end

    test "rejects a triple that is not three numbers" do
      assert_nil ColorSpace.parse("227, 6")
      assert_nil ColorSpace.parse("227, 6, 19, 4, 8")
    end

    # Four numbers are a CMYK build, three are an RGB triple. Every color
    # stores both spaces, so reading a build back as RGB is what lets a search
    # in either space find a color authored in the other.

    test "parses a cmyk build of four numbers" do
      assert_equal({ r: 0, g: 255, b: 255 }, ColorSpace.parse("100, 0, 0, 0"))
      assert_equal({ r: 255, g: 255, b: 0 }, ColorSpace.parse("0 0 100 0"))
    end

    test "parses a cmyk build with decimals and labels" do
      assert_equal({ r: 0, g: 0, b: 0 }, ColorSpace.parse("C 0 M 0 Y 0 K 100"))
      assert_equal ColorSpace.cmyk_to_rgb(0, 32.7, 77.6, 23.1), ColorSpace.parse("0, 32.7, 77.6, 23.1")
    end

    test "rejects a cmyk build outside 0..100" do
      assert_nil ColorSpace.parse("0, 0, 0, 101")
      assert_nil ColorSpace.parse("-1, 0, 0, 0")
    end

    test "three numbers stay an rgb triple" do
      assert_equal({ r: 0, g: 100, b: 100 }, ColorSpace.parse("0, 100, 100"))
    end

    test "returns nil for input it cannot read" do
      [ nil, "", "   ", "wat", "cornflower blue" ].each do |bad|
        assert_nil ColorSpace.parse(bad), "expected #{bad.inspect} to be unreadable"
      end
    end

    # --- Distance ----------------------------------------------------------

    test "distance is zero between a color and itself" do
      assert_equal 0.0, ColorSpace.distance({ r: 227, g: 6, b: 19 }, { r: 227, g: 6, b: 19 })
    end

    test "distance is symmetric" do
      a = { r: 12, g: 200, b: 90 }
      b = { r: 240, g: 30, b: 130 }

      assert_in_delta ColorSpace.distance(a, b), ColorSpace.distance(b, a), 0.0001
    end

    test "distance grows with how far apart two colors look" do
      base = { r: 128, g: 128, b: 128 }

      near = ColorSpace.distance(base, { r: 133, g: 133, b: 133 })
      far = ColorSpace.distance(base, { r: 168, g: 168, b: 168 })

      assert_operator near, :<, far
    end

    test "distance weighs green more heavily than red or blue" do
      base = { r: 100, g: 100, b: 100 }

      green = ColorSpace.distance(base, { r: 100, g: 130, b: 100 })
      red = ColorSpace.distance(base, { r: 130, g: 100, b: 100 })

      assert_operator green, :>, red
    end

    test "distance spans the whole space without overflowing it" do
      assert_operator ColorSpace.distance({ r: 0, g: 0, b: 0 }, { r: 255, g: 255, b: 255 }), :<=, 765
    end

    # --- Luma, chroma and hue ----------------------------------------------

    test "luma weighs green far above blue" do
      assert_operator ColorSpace.luma(0, 255, 0), :>, ColorSpace.luma(0, 0, 255)
    end

    test "luma calls yellow lighter than blue, where a mid-point would not" do
      assert_operator ColorSpace.luma(255, 255, 0), :>, ColorSpace.luma(0, 0, 255)
    end

    test "luma spans black to white" do
      assert_in_delta 0.0, ColorSpace.luma(0, 0, 0)
      assert_in_delta 255.0, ColorSpace.luma(255, 255, 255)
    end

    test "chroma is the spread between the channels" do
      assert_equal 0, ColorSpace.chroma(17, 17, 17)
      assert_equal 255, ColorSpace.chroma(255, 0, 0)
      assert_equal 5, ColorSpace.chroma(111, 111, 106)
    end

    test "hue runs red, orange, yellow, green, blue, violet round the wheel" do
      assert_in_delta 0.0, ColorSpace.hue(255, 0, 0)
      assert_in_delta 60.0, ColorSpace.hue(255, 255, 0)
      assert_in_delta 120.0, ColorSpace.hue(0, 255, 0)
      assert_in_delta 240.0, ColorSpace.hue(0, 0, 255)
      assert_in_delta 300.0, ColorSpace.hue(255, 0, 255)
    end

    test "hue is undefined for a color with no hue in it" do
      assert_nil ColorSpace.hue(17, 17, 17)
      assert_nil ColorSpace.hue(0, 0, 0)
      assert_nil ColorSpace.hue(255, 255, 255)
    end
  end
end
