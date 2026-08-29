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

  # Turbo and Stimulus arrive over an importmap, after the HTML they act on.
  # Waiting for markup is not waiting for behavior, and the gap between the
  # two is where round after round of CI failures lived: a click landing
  # before Turbo was listening submitted the form itself, with no dialog for
  # accept_confirm to find and no frame swap to wait on.
  #
  # Asked precisely, because the objects exist before either of them is doing
  # anything: Turbo sets window.Turbo when its module evaluates and starts
  # intercepting only at Turbo.start, and Stimulus is an application with no
  # controllers registered until it has read the DOM. Waiting on the objects
  # alone still let a test into that window.
  # An expression, not a statement: evaluate_script wraps what it is given and
  # a `return` here is a syntax error in the wrapper.
  READY = "!!(window.Turbo?.session?.started && window.Stimulus?.router?.modules?.length)"


  def visit(*)
    super

    await_javascript if javascript_driver?
  end

  def await_javascript
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time

    until page.evaluate_script(READY)
      raise "Turbo never started or Stimulus registered nothing" if
        Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end
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
  #
  # In two steps, because they fail for different reasons and the difference
  # is the whole diagnosis. If the sort never becomes the active one, the
  # navigation did not land and the list is still in whatever order it was.
  # Asserting straight on the list conflates that with a sort that landed and
  # ordered wrongly, and reports the second when it means the first.
  def sort_by(label, leading:, list: ".color-list", name: ".color-card__name")
    within("[data-filter=sort]") { click_on label }

    assert_selector "[data-filter=sort] .tag.active", text: label, exact_text: true
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

  # What the browser was actually looking at. Every CI failure in this suite
  # has been some form of "the interaction did not take effect", and the page
  # left behind separates a navigation that never happened from one that
  # happened and rendered something else.
  #
  # Printed rather than appended to the failure, because an error arrives
  # wrapped in a Minitest::UnexpectedError whose message is built on demand:
  # appending to it writes to a string nobody reads. Which is why the first
  # version of this reported nothing for exactly the failures it was written
  # for — the errors.
  #
  # Runs before super, because Rails resets the Capybara session in its own
  # before_teardown and there is nothing left to ask afterwards.
  def before_teardown
    report_browser_state if javascript_driver? && !passed?

    super
  end

  def report_browser_state
    puts "\n  [#{self.class}##{name}] the browser was at: #{page.current_url}"
    puts "  the page read: #{page.find('main').text.squish.truncate(400)}"
  rescue StandardError => e
    # Diagnosis must never become the reason a run fails.
    puts "  could not read the browser's state: #{e.class}: #{e.message}"
  end
end
