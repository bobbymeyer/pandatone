require "application_system_test_case"

# Half size or full, chosen the way every other view preference on these two
# screens is chosen: a register, a link, a parameter in the URL. Nothing about
# it is remembered on the server, so a link to a small index stays small for
# whoever it is sent to.
class CardSizeTest < ApplicationSystemTestCase
  test "each index offers the two sizes, and starts small" do
    [ colors_path, palettes_path ].each do |path|
      visit path

      within("[data-filter=size]") do
        assert_equal [ "Small", "Large" ], all("a").map(&:text)
        assert_selector ".tag.active", text: "Small", exact_text: true
      end
    end
  end

  test "choosing large says so in the url and on the register" do
    visit colors_path

    within("[data-filter=size]") { click_on "Large" }

    assert_current_path colors_path(size: "large")
    assert_selector "[data-filter=size] .tag.active", text: "Large", exact_text: true
  end

  test "a size nobody offers is small, not an error" do
    visit colors_path(size: "enormous")

    assert_selector "[data-filter=size] .tag.active", text: "Small", exact_text: true
  end

  # The three registers are one set of choices, so each has to survive the
  # others. This is the bug that would go unnoticed: a link built without it.
  test "the size survives a tag, an order and a search" do
    visit colors_path(size: "small")

    within("[data-filter=tag]") { click_on "brand" }
    assert_selector "[data-filter=size] .tag.active", text: "Small", exact_text: true

    within("[data-filter=sort]") { click_on "Added" }
    assert_selector "[data-filter=size] .tag.active", text: "Small", exact_text: true

    fill_in "Search", with: "signal"
    filter_unless_live
    assert_selector "[data-filter=size] .tag.active", text: "Small", exact_text: true
  end

  test "and the other choices survive the size" do
    visit colors_path(tag: "brand", sort: "added", q: "a")

    within("[data-filter=size]") { click_on "Small" }

    assert_selector "[data-filter=tag] .tag.active", text: "brand", exact_text: true
    assert_selector "[data-filter=sort] .tag.active", text: "Added", exact_text: true
    assert_equal "a", find_field("Search").value
  end
end
