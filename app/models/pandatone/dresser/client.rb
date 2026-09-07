require "net/http"

# Pandatone's v1 API, from the outside, for a consumer whose Pandatone is
# somewhere else. Versioned from its first commit precisely so a tool like
# this can depend on it.
module Pandatone
  module Dresser
    class Client
      PREFIX = "api/v1".freeze
      OPEN_TIMEOUT = 5
      READ_TIMEOUT = 15

      def self.configured
        new(url: Dresser.url, token: Dresser.token)
      end

      def initialize(url:, token:, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT)
        raise Dresser::Error, "no Pandatone url is configured" if url.blank?

        @base = URI.parse(url)
        @token = token
        @open_timeout, @read_timeout = open_timeout, read_timeout
      end

      # Every palette Pandatone has, with its colours.
      #
      # A request per palette, because the index carries id, name and tags and
      # no colours — and every filter a consumer applies is a question about
      # the colours: how many there are, and how light each one is. Fetched
      # once per catalogue and filtered locally, so this is paid once and the
      # catalogue answers from memory afterwards.
      def palettes
        palettes_json.map { |json| Palette.from_json(json) }
      end

      # The same, as the wire format: what Dresser.source answers.
      def palettes_json
        get(PREFIX, "palettes").map { |summary| get(PREFIX, "palettes", summary["id"].to_s) }
      end

      def palette(id)
        Palette.from_json(get(PREFIX, "palettes", id.to_s))
      end

      private
        def get(*segments)
          response = fetch(path_for(*segments))

          case response
          when Net::HTTPSuccess then parse(response.body)
          when Net::HTTPUnauthorized then raise Dresser::Unauthorized, "#{@base.host} refused the token"
          when Net::HTTPNotFound then raise Dresser::NotFound, path_for(*segments)
          else raise Dresser::Error, "#{@base.host} answered #{response.code}"
          end
        end

        def path_for(*segments)
          [ @base.path.chomp("/"), *segments ].join("/")
        end

        def fetch(path)
          request = Net::HTTP::Get.new(path)
          request["Authorization"] = "Bearer #{@token}" if @token.present?
          request["Accept"] = "application/json"

          http.request(request)
        rescue SystemCallError, Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError => e
          raise Dresser::Unreachable, "#{@base.host}: #{e.message}"
        end

        def http
          Net::HTTP.new(@base.host, @base.port).tap do |http|
            http.use_ssl = @base.scheme == "https"
            http.open_timeout = @open_timeout
            http.read_timeout = @read_timeout
          end
        end

        # A 200 carrying a proxy's error page is still not a catalogue.
        def parse(body)
          JSON.parse(body)
        rescue JSON::ParserError => e
          raise Dresser::Error, "#{@base.host} answered with something that is not json: #{e.message}"
        end
    end
  end
end
