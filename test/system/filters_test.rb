require "application_system_test_case"

# The block above the results on both indexes: a search, and the three
# registers of links under it. Four rows that read as parallel have to line up
# as parallel, so all of this is measured rather than declared.
class FiltersTest < ApplicationSystemTestCase
  test "the search field holds its line" do
    needs_a_browser

    [ colors_path, palettes_path ].each do |path|
      visit path

      # The field against the whole row, not against its own form: the form
      # collapses along with the field, so comparing the two would agree they
      # are fine.
      field = rect_of(".filter-form > .field")
      row = rect_of(".filters")

      assert_operator field["width"], :>, row["width"] / 3, "#{path}: the search field collapsed"
    end
  end

  # Three registers that read as parallel have to line up as parallel. The
  # labels differ in width, so without a shared column their controls start a
  # few pixels apart — and the search was a stacked field above them rather
  # than one of them at all.
  test "search, tags, sort and size are four registers sharing a label column" do
    needs_a_browser

    [ colors_path, palettes_path ].each do |path|
      visit path

      lefts = evaluate_script(<<~JS)
        [
          ['.filters .filter-form > .field > label', '.filters .filter-form > .field > input'],
          ...Array.from(document.querySelectorAll('.filter-row')).map(row =>
            [row.querySelector('.filter-row__label'), row.querySelector('.tag')])
        ].map(pair => pair.map(el =>
          Math.round((typeof el === 'string' ? document.querySelector(el) : el)
            .getBoundingClientRect().left)))
      JS

      assert_equal 4, lefts.size, "#{path}: expected a search, a tag, a sort and a size register"
      assert_equal 1, lefts.map(&:first).uniq.size, "#{path}: labels start in different columns: #{lefts.inspect}"
      assert_equal 1, lefts.map(&:last).uniq.size, "#{path}: controls start in different columns: #{lefts.inspect}"
    end
  end

  test "the sort options sit on one line of their own, below the search" do
    needs_a_browser

    visit colors_path

    field = rect_of(".filter-form > .field")
    sort = rect_of("[data-filter=sort]")

    assert_equal 1, tops_of("[data-filter=sort] li").uniq.size,
      "the sort options wrapped onto more than one line"
    assert_operator sort["top"], :>=, field["top"] + field["height"] - 1,
      "the sort options crowded onto the search line"
    assert_equal 0, evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth"),
      "the sort row pushed the page sideways"
  end

  # This is a color tool, so it is the last place that should lean on color
  # alone to say which of a row of choices is current. Computed, not declared:
  # the weight comes from a register shared with eight other selectors, and a
  # stylesheet grep would only ever find where it happens to be written.
  test "the current filter and sort are marked by more than their color" do
    needs_a_browser

    visit colors_path(tag: "brand")

    %w[ tag sort ].each do |register|
      weights = evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('[data-filter=#{register}] .tag'))
          .map(el => [el.classList.contains('active'), getComputedStyle(el).fontWeight])
      JS

      active = weights.select(&:first).map(&:last).map(&:to_i)
      rest = weights.reject(&:first).map(&:last).map(&:to_i)

      assert_equal 1, active.size, "expected one current choice in the #{register} register"
      assert_operator active.first, :>, rest.max,
        "the #{register} register marks its current choice by color alone"
    end
  end
end
