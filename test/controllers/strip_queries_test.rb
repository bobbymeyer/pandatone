require "test_helper"

module Pandatone
  # The palette strip renders every swatch of every palette it is given, so both
  # the palette index and the color page sit one missing preload away from a
  # query per palette. These pin the count flat in the number of palettes rather
  # than checking an exact number, which would only measure today's behavior.
  class StripQueriesTest < ActionDispatch::IntegrationTest
    setup { sign_in_as }

    test "the palette index does not issue a query per palette" do
      assert_query_count_flat palettes_path do
        palette_holding(colors(:deep_indigo))
      end
    end

    # The color orders read every swatch of every palette in Ruby, which is one
    # `palette.swatches` away from a query each.
    test "ordering the palette index by color does not issue a query per palette" do
      %w[ spectrum dark light ].each do |key|
        assert_query_count_flat palettes_path(sort: key) do
          palette_holding(colors(:deep_indigo))
        end
      end
    end

    test "a color page does not issue a query per palette holding it" do
      color = colors(:signal_red)

      assert_query_count_flat color_path(color) do
        palette_holding(color)
      end
    end

    private
      def assert_query_count_flat(path)
        get path
        before = count_queries { get path }

        3.times { yield }

        after = count_queries { get path }
        assert_equal before, after,
          "query count grew from #{before} to #{after} after adding 3 palettes"
      end

      def count_queries
        queries = 0
        counter = ->(_name, _start, _finish, _id, payload) do
          queries += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ])
        end

        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
        queries
      end

      def palette_holding(color)
        Palette.create!(name: "Extra #{SecureRandom.hex(4)}").tap do |palette|
          palette.palette_colors.create!(color: color)
        end
      end
  end
end
