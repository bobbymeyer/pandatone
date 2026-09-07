require "test_helper"

module Pandatone
  class Dresser::LuminanceTest < ActiveSupport::TestCase
    # The three sRGB primaries as OKLab publishes them. If the matrices or the
    # cube roots are wrong these are the numbers that move, and they are
    # quoted rather than computed so the test does not agree with the code by
    # construction.
    test "the sRGB primaries land where OKLab says they do" do
      assert_in_delta 0.627955, Dresser::Luminance.of(255, 0, 0), 1e-6
      assert_in_delta 0.866440, Dresser::Luminance.of(0, 255, 0), 1e-6
      assert_in_delta 0.452014, Dresser::Luminance.of(0, 0, 255), 1e-6
    end

    # White comes out at 0.99999999347, not at one. That is the spec's own
    # arithmetic, and the tolerance admits exactly that and nothing looser.
    test "black is nothing and white is everything, to the constants' own precision" do
      assert_in_delta 0.0, Dresser::Luminance.of(0, 0, 0), 1e-12
      assert_in_delta 1.0, Dresser::Luminance.of(255, 255, 255), 1e-8
    end

    # Half of 255 is not half the light. A mid grey reads at .60 rather than
    # .50, and any measure that puts it at .50 has skipped the gamma — which
    # is what the record's own luma does, and why this is measured here.
    test "mid grey is not half way" do
      assert_in_delta 0.599871, Dresser::Luminance.of(128, 128, 128), 1e-6
    end

    test "yellow reads lighter than blue" do
      assert_operator Dresser::Luminance.of(255, 255, 0), :>, Dresser::Luminance.of(0, 0, 255)
    end

    test "a hex reads the same as its channels, with or without the hash" do
      assert_equal Dresser::Luminance.of(227, 6, 19), Dresser::Luminance.of_hex("#E30613")
      assert_equal Dresser::Luminance.of(227, 6, 19), Dresser::Luminance.of_hex("e30613")
      assert_nil Dresser::Luminance.of_hex("red")
    end

    # The grey that measures a lightness is the inverse of measuring a grey.
    test "a grey round-trips through its lightness" do
      %w[ #000000 #808080 #FAF8F4 #FFFFFF ].each do |hex|
        level = hex[1..2].to_i(16)
        grey = Dresser::Luminance.grey(Dresser::Luminance.of(level, level, level))

        assert_equal format("#%02X%02X%02X", level, level, level), grey
      end
    end
  end
end
