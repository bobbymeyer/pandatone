# The orders an index offers, shared by colors and palettes because a
# library reads the same way whichever of the two you are looking at.
#
# Name, added and modified are what a database can express, so they stay in
# SQL. The three that turn on what something looks like are done in Ruby over
# rows the page loads anyway — expressing hue in SQL would mean a CASE over
# which channel is largest, written out again in every model that wanted it.
#
# What "dark" or "on the spectrum" means differs between one color and a
# palette of them, so each model answers that for itself.
module Sortable
  extend ActiveSupport::Concern

  # One word each. They sit in a row of six under "Sort by", where the row
  # itself says these are orders — so "Date added" spent two words saying what
  # the register above it had already said, and "first" said nothing at all.
  SORTS = {
    "name" => "Name",
    "added" => "Added",
    "modified" => "Modified",
    "spectrum" => "Color",
    "dark" => "Dark",
    "light" => "Light"
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
