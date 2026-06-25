require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "root page is accessible when signed out" do
    get root_path

    assert_response :success
    assert_select "h1", "Restaurant scheduling, without the complicated software."
    assert_select "a[href='#{new_user_session_path}']", text: "Sign In"
  end

  test "sign in page includes a sign up link" do
    get new_user_session_path

    assert_response :success
    assert_select "a[href='#{new_user_registration_path}']", text: "Sign Up"
  end

  test "a user with a current weekly schedule signs in to that schedule" do
    travel_to Date.new(2026, 6, 25) do
      post user_session_path, params: {
        user: {
          email: users(:manager).email,
          password: "password123"
        }
      }

      assert_redirected_to location_schedule_path(locations(:main), schedules(:main_week), section: "foh")
    end
  end

  test "signed-in root redirects to the current weekly schedule when it exists" do
    sign_in users(:manager)

    travel_to Date.new(2026, 6, 25) do
      get root_path
    end

    assert_redirected_to location_schedule_path(locations(:main), schedules(:main_week), section: "foh")
  end

  test "a user with a location but no current schedule signs in to the schedule list" do
    account = Account.create!(name: "New Grill")
    location = account.locations.create!(name: "Main Room")
    user = User.create!(
      first_name: "No",
      last_name: "Schedule",
      email: "no-schedule@example.com",
      password: "password123",
      password_confirmation: "password123",
      account: account
    )

    travel_to Date.new(2026, 6, 25) do
      post user_session_path, params: {
        user: {
          email: user.email,
          password: "password123"
        }
      }
    end

    assert_redirected_to location_schedules_path(location)
  end

  test "signed-in root redirects to the schedule list when no current schedule exists" do
    account = Account.create!(name: "Root Grill")
    location = account.locations.create!(name: "Dining Room")
    user = User.create!(
      first_name: "Root",
      last_name: "Owner",
      email: "root-owner@example.com",
      password: "password123",
      password_confirmation: "password123",
      account: account
    )
    sign_in user

    travel_to Date.new(2026, 6, 25) do
      get root_path
    end

    assert_redirected_to location_schedules_path(location)
  end

  test "a user with no active location signs in to the dashboard" do
    account = Account.create!(name: "Setup Grill")
    user = User.create!(
      first_name: "Setup",
      last_name: "Owner",
      email: "setup-owner@example.com",
      password: "password123",
      password_confirmation: "password123",
      account: account
    )

    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password123"
      }
    }

    assert_redirected_to dashboard_path
  end

  test "signed-in root redirects to dashboard when there is no active location" do
    account = Account.create!(name: "Inactive Grill")
    account.locations.create!(name: "Closed Room", active: false)
    user = User.create!(
      first_name: "Inactive",
      last_name: "Owner",
      email: "inactive-owner@example.com",
      password: "password123",
      password_confirmation: "password123",
      account: account
    )
    sign_in user

    get root_path

    assert_redirected_to dashboard_path
  end

  test "a signed-in user reaches the dashboard" do
    sign_in users(:manager)

    get dashboard_path

    assert_response :success
    assert_select "a[href='#{current_schedule_path}']", text: "Current Schedule"
    assert_select "h1", "Welcome, Mae"
    assert_select "h2", "This Week's Schedule"
    assert_select "h2", "Next Week's Schedule"
  end

  test "a signed-out visitor is redirected from dashboard to sign in" do
    get dashboard_path

    assert_redirected_to new_user_session_path
  end
end
