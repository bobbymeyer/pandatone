require "application_system_test_case"

# The library starts shut and with nobody holding a key. The first person to
# arrive makes one, and the door closes behind them.
class SignUpTest < ApplicationSystemTestCase
  test "an empty library sends the first visitor to sign up rather than to sign in" do
    empty_of_people

    visit colors_path

    assert_current_path new_registration_path
    assert_text "Open the library"
  end

  # There is nobody to be, so nothing asks you to be anybody. Every door leads
  # to the one thing that can be done.
  test "the sign in page sends the first visitor on to sign up" do
    empty_of_people

    visit new_session_path

    assert_current_path new_registration_path
    assert_text "Open the library"
  end

  test "so does the forgotten password page" do
    empty_of_people

    visit new_password_path

    assert_current_path new_registration_path
  end

  test "and the root of the app" do
    empty_of_people

    visit root_path

    assert_current_path new_registration_path
  end

  # Only while it is empty: once somebody is here, signing in is the way in.
  test "the sign in page is itself again once an account exists" do
    sign_out_completely

    visit new_session_path

    assert_current_path new_session_path
    assert_text "Sign in"
  end

  test "the first account is made an admin and closes sign ups behind it" do
    empty_of_people

    visit new_registration_path
    fill_in "Email", with: "first@example.com"
    fill_in "Password", with: "a good password"
    click_on "Open the library"

    assert_selector ".nav a", text: "Account"
    assert User.find_by(email_address: "first@example.com").admin?

    sign_out_completely
    visit new_registration_path

    assert_current_path new_session_path
    assert_text "Sign ups are closed"
  end

  test "an invited address may sign up, and arrives as an ordinary account" do
    Invitation.create!(email_address: "invited@example.com", invited_by: users(:keeper))
    sign_out_completely

    visit new_registration_path(email_address: "invited@example.com")
    fill_in "Email", with: "invited@example.com"
    fill_in "Password", with: "a good password"
    click_on "Create account"

    assert_selector ".nav a", text: "Account"
    assert_not User.find_by(email_address: "invited@example.com").admin?
  end

  test "an address nobody invited is refused" do
    Invitation.create!(email_address: "invited@example.com", invited_by: users(:keeper))
    sign_out_completely

    visit new_registration_path(email_address: "invited@example.com")
    fill_in "Email", with: "stranger@example.com"
    fill_in "Password", with: "a good password"
    click_on "Create account"

    assert_text "has not been invited"
    assert_nil User.find_by(email_address: "stranger@example.com")
  end

  # Spending it is what keeps the invitations page a list of people who have
  # not arrived rather than a list of everyone ever asked.
  test "signing up spends the invitation" do
    Invitation.create!(email_address: "invited@example.com", invited_by: users(:keeper))
    sign_out_completely

    visit new_registration_path(email_address: "invited@example.com")
    fill_in "Email", with: "invited@example.com"
    fill_in "Password", with: "a good password"
    click_on "Create account"

    assert_selector ".nav a", text: "Account"
    assert_not Invitation.invited?("invited@example.com")
  end

  private
    def empty_of_people
      Invitation.destroy_all
      User.destroy_all
      sign_out_completely
    end

    def sign_out_completely
      if javascript_driver?
        page.driver.browser.manage.delete_all_cookies
      else
        page.driver.browser.clear_cookies
      end
    end
end
