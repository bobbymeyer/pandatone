# The orders an index offers, shared by colours and palettes because a
# library reads the same way whichever of the two you are looking at.
#
# Name, added and modified are what a database can express, so they stay in
# SQL. The three that turn on what something looks like are done in Ruby over
# rows the page loads anyway — expressing hue in SQL would mean a CASE over
# which channel is largest, written out again in every model that wanted it.
#
# What "dark" or "on the spectrum" means differs between one colour and a
# palette of them, so each model answers that for itself.
module Sortable
  extend ActiveSupport::Concern

  SORTS = {
    "name" => "Name",
    "added" => "Date added",
    "modified" => "Date modified",
    "spectrum" => "Colour",
    "dark" => "Dark first",
    "light" => "Light first"
  }.freeze

  class_methods do
    def sorted(key)
      case key
      when "added"    then order(created_at: :desc, name: :asc)
      when "modified" then order(updated_at: :desc, name: :asc)
      when "spectrum" then by(&:spectrum_position)
      when "dark"     then by(&:dark_position)
      when "light"    then by(&:light_position)
      else                 order(:name)
      end
    end

    private
      # Name breaks every tie, so the order is total: two records that place
      # the same do not swap between one request and the next.
      def by(&position)
        order(:name).to_a.sort_by { |record| [ *position.call(record), record.name ] }
      end
  end
end
