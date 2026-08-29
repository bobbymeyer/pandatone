require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # These flows are driven through rack_test by default, which means the app
  # has to work with JavaScript switched off: Turbo Frames fall back to full
  # navigations and the Stimulus preview is pure enhancement on top of a form
  # that already submits. Set SYSTEM_TEST_DRIVER=selenium to run the same
  # flows in a real browser, where the frames and the live preview engage.
  if ENV["SYSTEM_TEST_DRIVER"] == "selenium"
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
  else
    driven_by :rack_test
  end

  # Turbo's confirmation is a real dialog in a browser and a no-op under
  # rack_test, which ignores the data attribute and just submits. Wrapping the
  # click keeps the flow identical under either driver.
  def confirming(&block)
    return yield if Capybara.current_driver == :rack_test

    accept_confirm(&block)
  end
end
