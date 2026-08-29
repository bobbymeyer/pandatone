require "application_system_test_case"

# The door itself. Every other flow starts already through it, so this is the
# only place the form is actually driven.
class SignInTest < ApplicationSystemTestCase
  test "signs in through the form and lands in the library" do
    sign_out_completely

    visit new_session_path
    fill_in "Email", with: users(:keeper).email_address
    fill_in "Password", with: "password"
    click_on "Sign in"

    assert_selector ".masthead__nav a", text: "Account"
    assert_text "Palettes"
  end

  test "refuses a password that is not the one on the account" do
    sign_out_completely

    visit new_session_path
    fill_in "Email", with: users(:keeper).email_address
    fill_in "Password", with: "not-the-password"
    click_on "Sign in"

    assert_text "Try another email address or password"
    assert_no_selector ".masthead__nav a", text: "Account"
  end

  test "sends a signed out visitor to the sign in page rather than to the library" do
    sign_out_completely

    visit colors_path

    assert_current_path new_session_path
    assert_no_text "signal-red"
  end

  private
    # The shared setup plants a cookie; these tests need it gone.
    def sign_out_completely
      Capybara.current_session.driver.browser.manage.delete_all_cookies if javascript_driver?
      page.driver.browser.clear_cookies unless javascript_driver?
    end
end
