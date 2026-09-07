require "test_helper"

module Pandatone
  # The picker, rendered the way a consumer renders it: the catalogue split
  # into what can dress the thing and what cannot, and a URL for each.
  class Dresser::PickerTest < ActionView::TestCase
    include Pandatone::DresserHelper

    # Demoted, not excluded. A slot taken away brings the rest back into
    # range, so hiding them would hide the thing that changes.
    test "puts what can dress the thing first and keeps the rest" do
      render partial: "pandatone/dresser/picker", locals: {
        slot_count: 3, serving: [ dresser_palette("#FAF8F4", "#C1272D", "#12120F", id: 2, name: "Deck Chair") ],
        demoted: [ dresser_palette("#FFFFFF", "#101010", id: 1, name: "Two Tone") ],
        dress_url: ->(palette) { "/awnings/1/colorways?palette_id=#{palette.id}" }, refresh_url: "/awnings/1/colorways/new?refresh=1",
        noun: "this awning"
      }

      assert_select "section.palettes", 2
      assert_select "section.palettes:first-of-type h2", text: "Can dress this awning"
      assert_select "section.palettes:first-of-type tbody tr", 1
      assert_select "section.palettes:first-of-type form[action='/awnings/1/colorways?palette_id=2'] button", text: "Dress"
      assert_select "section.palettes:last-of-type td", text: "1 short"
      assert_select ".palette-swatch", 5
      assert_select "a.button--quiet[href='/awnings/1/colorways/new?refresh=1']", text: "Refresh from Pandatone"
    end

    # Composing needs nothing from Pandatone; only dressing does. So the picker
    # says what happened rather than falling over.
    test "Pandatone not answering is said out loud, not a blank catalogue" do
      render partial: "pandatone/dresser/picker", locals: {
        slot_count: 3, serving: [], demoted: [], dress_url: ->(_) { "/" }, refresh_url: "/",
        unreachable: Dresser::Unreachable.new("pandatone.test: Connection refused")
      }

      assert_select ".empty", text: /did not answer: pandatone.test: Connection refused/
      assert_select "section.palettes", 0
    end

    test "the actions on a colorway are drift and taking off, and when it was taken" do
      wearer = Wearer.create!(name: "Awning", slot_count: 2)
      colorway = wearer.colorways.create!(palette: dresser_palette("#FAF8F4", "#12120F"))

      render partial: "pandatone/dresser/actions", locals: { colorway: colorway, drift_url: "/drift", remove_url: "/remove" }

      assert_select "form[action='/drift'] button", text: "Check for drift"
      assert_select "form[action='/remove'] button", text: "Take off"
      assert_select ".micro", text: /Taken/
    end
  end
end
