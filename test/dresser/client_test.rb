require "test_helper"

module Pandatone
  class Dresser::ClientTest < ActiveSupport::TestCase
    setup { @client = Dresser::Client.new(url: "https://pandatone.test", token: "sekrit") }

    test "the token goes out as a bearer credential" do
      index = stub_index([])

      @client.palettes

      assert_requested index.with(headers: { "Authorization" => "Bearer sekrit", "Accept" => "application/json" })
    end

    # The index carries id, name and tags and no colours, and every filter a
    # consumer applies is a question about the colours. So the colours are
    # fetched a palette at a time, once, and the catalogue answers from memory
    # afterwards.
    test "colours are fetched per palette, because the index does not carry them" do
      stub_index([ summary(1, "Warm"), summary(2, "Cool") ])
      warm = stub_palette(1, "Warm", "#FAF8F4", "#12120F")
      cool = stub_palette(2, "Cool", "#0000FF")

      palettes = @client.palettes

      assert_requested warm
      assert_requested cool
      assert_equal [ "Warm", "Cool" ], palettes.map(&:name)
      assert_equal [ 2, 1 ], palettes.map(&:size)
      assert_in_delta 0.98, palettes.first.ranked.first.luminance, 0.005
    end

    # Each of these would otherwise read as "Pandatone has no palettes", and a
    # catalogue that is empty because the token is wrong is worse than one
    # that says so: every colorway would rerender against nothing.
    test "a refused token is not an empty catalogue" do
      stub_request(:get, "https://pandatone.test/api/v1/palettes").to_return(status: 401, body: '{"error":"Unauthorized"}')

      assert_raises(Dresser::Unauthorized) { @client.palettes }
    end

    test "a server that is not there is not an empty catalogue" do
      stub_request(:get, "https://pandatone.test/api/v1/palettes").to_raise(Errno::ECONNREFUSED)

      assert_raises(Dresser::Unreachable) { @client.palettes }
    end

    test "a page that is not json is not a catalogue" do
      stub_request(:get, "https://pandatone.test/api/v1/palettes").to_return(body: "<html>proxy error</html>")

      assert_raises(Dresser::Error) { @client.palettes }
    end

    test "no url is refused before anything is asked" do
      assert_raises(Dresser::Error) { Dresser::Client.new(url: nil, token: "x") }
    end

    private
      def summary(id, name)
        { id: id, name: name, tags: [] }
      end

      def stub_index(summaries)
        stub_request(:get, "https://pandatone.test/api/v1/palettes")
          .to_return(body: summaries.to_json, headers: { "Content-Type" => "application/json" })
      end

      def stub_palette(id, name, *hexes)
        stub_request(:get, "https://pandatone.test/api/v1/palettes/#{id}")
          .to_return(body: wire_palette(id, name, hexes).to_json, headers: { "Content-Type" => "application/json" })
      end
  end
end
