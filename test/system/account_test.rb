require "application_system_test_case"

# Where you find out who you are signed in as, read the credential your
# scripts carry, and take it away from them.
class AccountTest < ApplicationSystemTestCase
  test "reaches the account from anywhere in the app" do
    visit colors_path

    click_on "Account"

    assert_text users(:keeper).email_address
  end

  test "shows the token, because a credential you cannot read is no use" do
    visit account_path

    assert_text users(:keeper).api_token
  end

  # The same copy button a hex gets. It is on screen to be taken somewhere
  # else, which is the whole definition of the control.
  test "the token is a copy button carrying its own value" do
    visit account_path

    button = find(".copy")
    assert_equal users(:keeper).api_token, button["data-its-swiss-clipboard-text-value"]
  end

  test "regenerating replaces the token on the page" do
    was = users(:keeper).api_token

    visit account_path
    confirming { click_on "Regenerate token" }

    assert_no_text was
    assert_text users(:keeper).reload.api_token
  end

  test "says what regenerating will cost before it is done" do
    visit account_path

    assert_equal "Every script and tool using the current token stops working until you give it the new one. Regenerate it?",
      find_button("Regenerate token")[:"data-turbo-confirm"]
  end

  test "signing out ends the session and asks for it again" do
    visit account_path

    click_on "Sign out"

    assert_current_path new_session_path
    assert_text "Sign in"
  end

  test "a signed out visitor is sent to the sign in page, not to the library" do
    visit account_path
    click_on "Sign out"

    visit colors_path

    assert_current_path new_session_path
    assert_no_text "signal-red"
  end
end
