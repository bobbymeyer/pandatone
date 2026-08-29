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
    Selenium::WebDriver::Chrome::Service.driver_path = ENV["CHROMEDRIVER"] if ENV["CHROMEDRIVER"]

    driven_by :selenium, using: :headless_chrome, screen_size: SCREEN_SIZE do |options|
      options.binary = ENV["CHROME_BINARY"] if ENV["CHROME_BINARY"]
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
    end
  else
    driven_by :rack_test
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
end
