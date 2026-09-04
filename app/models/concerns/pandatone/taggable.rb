# Tags are the discovery mechanism for both palettes and colors: there is no
# "active" boolean anywhere, just a palette tagged "active". That makes tag
# handling load-bearing, so it is normalized in one place and queried in one
# place.
module Pandatone
  module Taggable
    extend ActiveSupport::Concern

    included do
      before_validation :normalize_tags
      validate :tags_must_be_a_list_of_strings

      # Matches whole tags only. Tags are stored downcased, so the needle is too.
      scope :tagged, ->(tag) {
        tag = tag.to_s.strip.downcase
        next none if tag.blank?

        where("EXISTS (SELECT 1 FROM json_each(#{table_name}.tags) WHERE json_each.value = ?)", tag)
      }
    end

    class_methods do
      # Every tag actually in use, for building a filter bar. Cheap enough at
      # this scale to ask the database each time.
      def all_tags
        connection.select_values(
          "SELECT DISTINCT json_each.value FROM #{table_name}, json_each(#{table_name}.tags) ORDER BY 1"
        )
      end

      # Accepts either a list or a comma-separated string, so the same writer
      # serves a JSON API body and a text field in a form.
      def normalize_tags(value)
        list = case value
        when nil    then []
        when String then value.split(",")
        else             value
        end

        list.map { |tag| tag.to_s.strip.downcase }.reject(&:blank?).uniq
      end
    end

    def tag_list
      tags.join(", ")
    end

    def tag_list=(value)
      self.tags = value
    end

    private
      def normalize_tags
        self.tags = self.class.normalize_tags(tags) if tags.nil? || tags.is_a?(Array) || tags.is_a?(String)
      end

      def tags_must_be_a_list_of_strings
        return if tags.is_a?(Array) && tags.all?(String)

        errors.add(:tags, "must be an array of strings")
      end
  end
end
