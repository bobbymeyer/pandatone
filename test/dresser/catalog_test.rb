require "test_helper"

module Pandatone
  class Dresser::CatalogTest < ActiveSupport::TestCase
    setup { Dresser::Catalog.forget! }
    teardown { Dresser::Catalog.forget! }

    # Fetch once, filter locally. Filtering is a question about colours that
    # are already in hand, and asking Pandatone again for every change of slot
    # count would put a round trip behind a control.
    test "the catalogue is fetched once however often it is filtered" do
      source = CountingSource.new(palettes)
      catalog = Dresser::Catalog.new(source)

      catalog.serving(2)
      catalog.serving(4)
      catalog.cycling(6)
      catalog.find(1)

      assert_equal 1, source.fetches
    end

    test "serving needs a colour for every slot, and cycling needs the size to divide" do
      catalog = Dresser::Catalog.new(CountingSource.new(palettes))

      assert_equal [ "Two", "Three", "Six" ], catalog.serving(2).map(&:name)
      assert_equal [ "Six" ], catalog.serving(4).map(&:name)
      assert_equal [ "Two" ], catalog.cycling(4).map(&:name)
      assert_equal "Three", catalog.find("2").name
    end

    # With no URL configured, the Pandatone in this process answers, through
    # its public methods and in its wire format — which is what a host that
    # mounts both tools gets without writing a line.
    test "unconfigured, the source is the Pandatone in this process" do
      was = Dresser.url
      Dresser.url = nil

      names = Dresser::Catalog.current.palettes.map(&:name)

      assert_equal Pandatone.palettes.map { |palette| palette[:name] }.sort, names.sort
      assert_operator Dresser::Catalog.current.palettes.sum(&:size), :>, 0, "the palettes came with their colours"
    ensure
      Dresser.url = was
    end

    test "with a URL, the source is that Pandatone over HTTP" do
      was = [ Dresser.url, Dresser.token ]
      Dresser.url, Dresser.token = "https://pandatone.test", "sekrit"
      stub_request(:get, "https://pandatone.test/api/v1/palettes").to_return(body: "[]", headers: { "Content-Type" => "application/json" })

      assert_empty Dresser::Catalog.current.palettes
    ensure
      Dresser.url, Dresser.token = was
    end

    test "the current catalogue is held for a while and forgotten on request" do
      source = CountingSource.new(palettes)
      Dresser::Catalog.current(source).palettes
      Dresser::Catalog.current(source).palettes
      assert_equal 1, source.fetches

      Dresser::Catalog.forget!
      Dresser::Catalog.current(source).palettes
      assert_equal 2, source.fetches
    end

    private
      def palettes
        [ built("Two", 2, id: 1), built("Three", 3, id: 2), built("Six", 6, id: 3) ]
      end

      def built(name, size, id:)
        colors = Array.new(size) do |index|
          level = index * (255 / size)
          { "id" => (id * 100) + index, "name" => "c#{index}", "hex" => "#000000", "rgb" => { "r" => level, "g" => level, "b" => level } }
        end

        { "id" => id, "name" => name, "tags" => [], "colors" => colors }
      end

      class CountingSource
        attr_reader :fetches

        def initialize(palettes)
          @palettes = palettes
          @fetches = 0
        end

        def call
          @fetches += 1
          @palettes
        end
      end
  end
end
