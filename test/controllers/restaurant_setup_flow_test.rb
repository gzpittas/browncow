require "test_helper"

class RestaurantSetupFlowTest < ActionDispatch::IntegrationTest
  test "a signing-in user without an account is directed to account setup" do
    user = User.create!(
      first_name: "New",
      last_name: "Manager",
      email: "new-manager@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password123"
      }
    }

    assert_redirected_to new_account_path
  end

  test "creating an account sends the user to the dashboard" do
    user = User.create!(
      first_name: "New",
      last_name: "Owner",
      email: "new-owner@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in user

    post account_path, params: {
      account: {
        name: "Corner Bistro",
        phone_number: "555-0199",
        email: "hello@corner.example"
      }
    }

    assert_redirected_to dashboard_path
    assert_equal "Corner Bistro", user.reload.account.name
  end

  test "a signed-in user can create a location" do
    sign_in users(:manager)

    assert_difference -> { users(:manager).account.locations.count }, 1 do
      post locations_path, params: {
        location: {
          name: "Patio",
          city: "Buffalo",
          state: "NY"
        }
      }
    end

    assert_redirected_to locations_path
  end

  test "a signed-in user can create positions for their location" do
    sign_in users(:manager)
    location = locations(:main)

    assert_difference -> { location.positions.count }, 1 do
      post location_positions_path(location), params: {
        position: {
          name: "Line Cook"
        }
      }
    end

    assert_redirected_to location_positions_path(location)
  end

  test "a signed-in user can create an employee and assign positions" do
    sign_in users(:manager)
    location = locations(:main)

    assert_difference -> { location.employees.count }, 1 do
      post location_employees_path(location), params: {
        employee: {
          first_name: "Jordan",
          last_name: "Cook",
          email: "jordan@example.com",
          position_ids: [ positions(:server).id, positions(:bartender).id ]
        }
      }
    end

    employee = location.employees.find_by!(email: "jordan@example.com")
    assert_equal [ "Bartender", "Server" ], employee.positions.order(:name).pluck(:name)
    assert_redirected_to location_employees_path(location)
  end

  test "a user cannot access another account location" do
    sign_in users(:manager)

    get edit_location_path(locations(:other))
    assert_response :not_found
  end

  test "a user cannot access another account position" do
    sign_in users(:manager)

    get edit_location_position_path(locations(:other), positions(:other_server))
    assert_response :not_found
  end

  test "a user cannot access another account employee" do
    sign_in users(:manager)

    get edit_location_employee_path(locations(:other), employees(:other_employee))
    assert_response :not_found
  end
end
