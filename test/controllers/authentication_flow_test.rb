require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "root page is accessible when signed out" do
    get root_path

    assert_redirected_to new_user_session_path
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

      assert_redirected_to location_schedule_path(locations(:main), schedules(:main_week), view: "positions", section: "foh")
    end
  end

  test "signed-in root redirects to the current weekly schedule when it exists" do
    sign_in users(:manager)

    travel_to Date.new(2026, 6, 25) do
      get root_path
    end

    assert_redirected_to location_schedule_path(locations(:main), schedules(:main_week), view: "positions", section: "foh")
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
    assert_select "a[href='#{current_schedule_path}'].navbar-current-schedule-btn.current-menu-toggle[aria-label='Current Schedule'][data-bs-toggle='tooltip'][data-bs-title='Current Schedule'] .fa-solid.fa-clock", count: 1
    assert_select ".navbar-current-schedule-control .cta-label", text: "CURRENT"
    assert_select ".navbar-settings-control .navbar-settings-btn .fa-solid.fa-gear", count: 1
    assert_select ".navbar-settings-control .cta-label", text: "SETTINGS"
    assert_select ".navbar .navbar-cta-btn", count: 0
    assert_select ".dropdown-menu a[href='#{positions_path}']", text: "Positions"
    assert_select ".dropdown-menu a[href='#{employees_path}']", text: "Employees"
    assert_select ".dropdown-menu a[href='#{schedules_path}']", text: "Schedules"
    assert_select ".dropdown-menu a[href='#{dashboard_path}']", text: "Dashboard"
    assert_select ".dropdown-menu a[href='#{locations_path}']", text: "Locations"
    assert_select ".dropdown-menu a[href='#{edit_account_path}']", text: "Account"
    assert_select ".dropdown-menu form[action='#{destroy_user_session_path}'] button", text: "Sign Out"
    assert_select "h1", "Welcome, Mae"
    assert_select "h2", "This Week's Schedule"
    assert_select "h2", "Next Week's Schedule"
  end

  test "a signed-out visitor is redirected from dashboard to sign in" do
    get dashboard_path

    assert_redirected_to new_user_session_path
  end
end
