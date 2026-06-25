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
          name: "Line Cook",
          section: "boh",
          color: "#B85C38"
        }
      }
    end

    assert_equal "#B85C38", location.positions.find_by!(name: "Line Cook").color
    assert_redirected_to location_positions_path(location)
  end

  test "position form renders the color palette" do
    sign_in users(:manager)

    get new_location_position_path(locations(:main))

    assert_response :success
    assert_select "select[name='position[section]']"
    assert_select "input[name='position[color]'][type=radio]", count: Position::COLOR_PALETTE.size
    assert_select "input[name='position[color]'][value='#{Position::COLOR_PALETTE.first}'][checked]"
    assert_select ".position-color-swatch", count: Position::COLOR_PALETTE.size
  end

  test "a signed-in user can update a position color" do
    sign_in users(:manager)

    patch location_position_path(locations(:main), positions(:server)), params: {
      position: {
        name: "Server",
        section: "foh",
        color: "#3F8F5F"
      }
    }

    assert_redirected_to location_positions_path(locations(:main))
    assert_equal "#3F8F5F", positions(:server).reload.color
  end

  test "a signed-in user can reorder positions within a division" do
    sign_in users(:manager)

    get location_positions_path(locations(:main))

    assert_response :success
    assert_select "tbody[data-controller='position-sort']", minimum: 1
    assert_select ".position-drag-handle", minimum: 1

    patch reorder_location_positions_path(locations(:main)), params: {
      position: {
        section: "foh",
        ordered_ids: [ positions(:bartender).id, positions(:server).id ]
      }
    }, as: :json

    assert_response :success
    assert_equal [ "Bartender", "Server" ], locations(:main).positions.foh.ordered.pluck(:name)
  end

  test "a position cannot be reordered into a different division" do
    sign_in users(:manager)

    patch reorder_location_positions_path(locations(:main)), params: {
      position: {
        section: "boh",
        ordered_ids: [ positions(:server).id ]
      }
    }, as: :json

    assert_response :unprocessable_entity
  end

  test "reorder rejects missing positions from the submitted division list" do
    sign_in users(:manager)

    patch reorder_location_positions_path(locations(:main)), params: {
      position: {
        section: "foh",
        ordered_ids: [ positions(:server).id, 999_999 ]
      }
    }, as: :json

    assert_response :unprocessable_entity
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

  test "employees are listed in first-name order" do
    sign_in users(:manager)
    locations(:main).employees.create!(
      first_name: "Alex",
      last_name: "Zed",
      email: "alex-zed@example.com"
    )

    get location_employees_path(locations(:main))

    assert_response :success
    assert_match(/Alex Zed.*Sam Server/m, response.body)
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
