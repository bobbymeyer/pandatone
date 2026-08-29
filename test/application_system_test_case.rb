require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  SCREEN_SIZE = [ 1400, 1400 ].freeze

  # These flows are driven through rack_test by default, which means the app
  # has to work with JavaScript switched off: Turbo Frames fall back to full
  # navigations and the Stimulus preview is pure enhancement on top of a form
  # that already submits. Set SYSTEM_TEST_DRIVER=selenium to run the same
  # flows in a real browser, where the frames and the live preview engage.
  if ENV["SYSTEM_TEST_DRIVER"] == "selenium"
    # CHROME_BINARY / CHROMEDRIVER let a machine point at browsers it already
    # has instead of downloading a pair. CI leaves both unset and Selenium
    # Manager sorts it out.
    Selenium::WebDriver::Chrome::Service.driver_path = ENV["CHROMEDRIVER"] if ENV["CHROMEDRIVER"].present?

    # Two seconds is Capybara's default and a desktop-speed assumption. Before
    # a browser test can assert anything, the page has to fetch an importmap,
    # connect Stimulus and swap a Turbo Frame, and a shared CI runner does all
    # of that at a fraction of the speed this was written on — slowest of all
    # for the first test in a process, against a browser that has cached
    # nothing yet. This is a budget, not a weaker assertion: every matcher
    # still has to come true, and one that never does still fails after it.
    Capybara.default_max_wait_time = 10

    driven_by :selenium, using: :headless_chrome, screen_size: SCREEN_SIZE do |options|
      options.binary = ENV["CHROME_BINARY"] if ENV["CHROME_BINARY"].present?
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
    end
  else
    driven_by :rack_test
  end

  # Every screen in this app is behind the sign-in, so every flow through one
  # starts signed in. Going through the form rather than planting the cookie
  # keeps this honest under both drivers: it is the same act a person performs,
  # and it fails loudly if the sign-in itself breaks.
  setup do
    visit new_session_path
    fill_in "Email", with: users(:keeper).email_address
    fill_in "Password", with: "password"
    click_on "Sign in"

    # Waits for the sign-in to actually land. A browser submits the form
    # asynchronously, so without something to wait on the next visit races the
    # redirect and lands back on the sign-in page with the library still shut.
    assert_selector ".masthead__nav a", text: "Account"
  end

  # rack_test has no CSS, no box model and no JavaScript, so anything about
  # layout or behavior has to say so and stand aside.
  def javascript_driver?
    Capybara.current_driver != :rack_test
  end

  # Turbo's confirmation is a real dialog in a browser and a no-op under
  # rack_test, which ignores the data attribute and just submits. Wrapping the
  # click keeps the flow identical under either driver.
  def confirming(&block)
    return yield if Capybara.current_driver == :rack_test

    accept_confirm(&block)
  end

  # --- Shared reading helpers ----------------------------------------------

  # Choosing an order is a whole navigation, so this waits for the reordered
  # list before handing back: reading the names does not retry.
  def sort_by(label, leading:, list: ".color-list", name: ".color-card__name")
    within("[data-filter=sort]") { click_on label }

    assert_selector "#{list} > li:first-child #{name}", text: leading, exact_text: true
  end

  # Reading a collection is two steps — find the nodes, then ask each for its
  # text — and a view transition can swap them in between. synchronize is
  # Capybara's own answer: it retries the block on a stale node, and runs it
  # once under rack_test, where nothing moves.
  def names_in(selector)
    page.document.synchronize do
      all(selector, minimum: 1).map(&:text)
    end
  end

  def card_names = names_in(".color-card__name")
  def strip_names = names_in(".palette-list .palette-strip__name")

  # rack_test has no JavaScript, so a live-filtering form needs its button.
  def filter_unless_live
    click_on "Filter" unless javascript_driver?
  end
end
