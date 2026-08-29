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
  # starts signed in — by planting the session cookie, not by driving the form.
  #
  # Driving it was the honest-looking choice and it was the wrong one. Turbo
  # will not begin a form submission while another is in progress, and a
  # browser leaves the sign-in POST in flight when Capybara navigates away
  # from it. The next form the test submits is then silently ignored: a click
  # on a submit button that does nothing at all, on a page that still looks
  # right. Every browser failure on CI since the sign-in went in has been some
  # version of "the interaction did not take effect", and this is the one
  # thing all of those tests newly had in common.
  #
  # The form itself is not left untested — sign_in_test.rb drives it.
  setup do
    visit new_session_path
    plant_session_cookie
  end

  # A fixture session, so the row is there in every test and the cookie can be
  # written without asking the app for anything.
  def plant_session_cookie
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar.signed[:session_id] = sessions(:keeper).id

    if javascript_driver?
      page.driver.browser.manage.add_cookie(name: "session_id", value: jar[:session_id], path: "/")
    else
      page.driver.browser.set_cookie("session_id=#{jar[:session_id]}")
    end
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
  # What has to be true before a test may touch the page. Expressions, not
  # statements: evaluate_script wraps what it is given and a `return` is a
  # syntax error in the wrapper.
  #
  # Turbo sets window.Turbo when its module evaluates and starts intercepting
  # only at Turbo.start; Stimulus is an application with no controllers until
  # it has read the DOM; data-turbo-preview is Turbo's own flag for "this is a
  # cached snapshot, the real page is still coming"; and a running
  # ::view-transition animation means the browser is painting a snapshot of
  # the page over the page. A click during any of those lands on a DOM that is
  # about to be replaced, or on an image of one — and afterwards it is
  # indistinguishable from a click that did nothing, which is what every CI
  # failure in this suite has looked like.
  CONDITIONS = {
    "Turbo started" => "!!window.Turbo?.session?.started",
    "Stimulus registered a controller" => "!!window.Stimulus?.router?.modules?.length",
    "no cached preview on screen" => "!document.documentElement.hasAttribute('data-turbo-preview')",
    "no view transition running" => <<~JS.squish
      !document.getAnimations().some(a =>
        String(a.effect?.pseudoElement || '').startsWith('::view-transition'))
    JS
  }.freeze

  SETTLED = CONDITIONS.values.map { |condition| "(#{condition})" }.join(" && ").freeze

  def visit(*)
    super

    await_page if javascript_driver?
  end

  # Every way a test reaches for the page, held to the same condition. Gating
  # only visit was not enough: the interaction that fails is usually the one
  # after a click, while that click's own navigation is still transitioning.
  %i[ click_on click_link click_button choose fill_in check uncheck select ].each do |interaction|
    define_method(interaction) do |*args, **options, &block|
      await_page if javascript_driver?

      super(*args, **options, &block)
    end
  end

  def await_page
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time

    until page.evaluate_script(SETTLED)
      raise "the page never settled: #{unmet_conditions.to_sentence} " if
        Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end
  end

  # Which of them is still false, so a timeout names the one that held it up
  # rather than leaving all four as suspects.
  def unmet_conditions
    CONDITIONS.reject { |_, condition| page.evaluate_script(condition) }.keys.map { |name| "never saw #{name}" }
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

  # For a test that measures something: rack_test has no box model, so it can
  # pass a page whose layout has collapsed entirely.
  def needs_a_browser
    skip "needs a real browser; run with SYSTEM_TEST_DRIVER=selenium" unless javascript_driver?
  end

  def widths_of(selector)
    evaluate_script(
      "Array.from(document.querySelectorAll(#{selector.to_json}))" \
      ".map(el => Math.round(el.getBoundingClientRect().width))"
    )
  end

  def width_of(selector)
    evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().width")
  end

  def tops_of(selector)
    evaluate_script(
      "Array.from(document.querySelectorAll(#{selector.to_json}))" \
      ".map(el => Math.round(el.getBoundingClientRect().top))"
    )
  end

  def rect_of(selector)
    evaluate_script(
      "(({top, left, width, height}) => ({top, left, width, height}))" \
      "(document.querySelector(#{selector.to_json}).getBoundingClientRect())"
    )
  end

  def font_size_of(selector)
    evaluate_script(
      "parseFloat(getComputedStyle(document.querySelector(#{selector.to_json})).fontSize)"
    )
  end

  # Visibility as the browser computes it, not as the markup implies: the
  # thing being tested is usually a CSS rule deciding what is showing.
  def assert_visible(selector)
    assert find(selector, visible: :all).visible?, "#{selector} should be showing"
  end

  def assert_hidden(selector)
    assert_not find(selector, visible: :all).visible?, "#{selector} should be hidden"
  end

  # Chrome refuses clipboard writes to an unfocused or unpermitted page.
  def grant_clipboard
    page.driver.browser.execute_cdp("Browser.grantPermissions",
      origin: page.server_url, permissions: %w[ clipboardReadWrite clipboardSanitizedWrite ])
  end

  # rack_test has no JavaScript, so a live-filtering form needs its button —
  # and a real browser has already submitted by the time this is called, and
  # has taken the button away for saying so.
  def filter_unless_live
    click_on "Search" unless javascript_driver?
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
    report_browser_state if javascript_driver? && !passed? && !skipped?

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
