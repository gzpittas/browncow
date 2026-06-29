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

  test "a signed-in user can configure the public schedule link" do
    sign_in users(:manager)

    get edit_account_path

    assert_response :success
    assert_select "input[name='account[public_schedule_enabled]']"
    assert_select "input[name='account[public_schedule_slug]']"
    assert_select "input[name='account[public_schedule_password]'][type=password]"

    patch account_path, params: {
      account: {
        name: accounts(:main).name,
        phone_number: accounts(:main).phone_number,
        email: accounts(:main).email,
        public_schedule_enabled: "1",
        public_schedule_slug: "athens",
        public_schedule_password: "staff-only"
      }
    }

    account = accounts(:main).reload

    assert_redirected_to dashboard_path
    assert account.public_schedule_enabled?
    assert_equal "athens", account.public_schedule_slug
    assert account.public_schedule_password_authenticated?("staff-only")
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

  test "a signed-in user can delete a position and its shifts" do
    sign_in users(:manager)
    position_id = positions(:server).id
    shift_id = shifts(:sam_monday).id

    assert_difference -> { locations(:main).positions.count }, -1 do
      assert_difference -> { schedules(:main_week).shifts.count }, -1 do
        delete location_position_path(locations(:main), positions(:server))
      end
    end

    assert_redirected_to location_positions_path(locations(:main))
    assert_nil Position.find_by(id: position_id)
    assert_nil Shift.find_by(id: shift_id)
  end

  test "positions list shows a delete button for each position" do
    sign_in users(:manager)

    get location_positions_path(locations(:main))

    assert_response :success
    assert_select "form[action='#{location_position_path(locations(:main), positions(:server))}'] button", text: "Delete"
  end

  test "edit position page includes a visible delete action" do
    sign_in users(:manager)

    get edit_location_position_path(locations(:main), positions(:server))

    assert_response :success
    assert_select "form[action='#{location_position_path(locations(:main), positions(:server))}'] button", text: "Delete Position"
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
    assert_match(/FOH.*Sam Server/m, response.body)
    assert_match(/Unassigned.*Alex Zed/m, response.body)
  end

  test "employees index is split into foh and boh sections" do
    sign_in users(:manager)
    boh_position = locations(:main).positions.create!(name: "Prep Cook", section: "boh", color: Position::COLOR_PALETTE.first)
    boh_employee = locations(:main).employees.create!(
      first_name: "Casey",
      last_name: "Cook",
      email: "casey-cook@example.com"
    )
    boh_employee.positions << boh_position

    get location_employees_path(locations(:main))

    assert_response :success
    assert_select ".employee-division-section .card-header h2", text: "FOH"
    assert_select ".employee-division-section .card-header h2", text: "BOH"
    assert_select ".employee-division-section", text: /Sam Server/
    assert_select ".employee-division-section", text: /Casey Cook/
    assert_match(/FOH.*Sam Server/m, response.body)
    assert_match(/BOH.*Casey Cook/m, response.body)
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

  test "a user cannot delete another account position" do
    sign_in users(:manager)

    assert_no_difference -> { Position.count } do
      delete location_position_path(locations(:other), positions(:other_server))
    end

    assert_response :not_found
  end

  test "a user cannot access another account employee" do
    sign_in users(:manager)

    get edit_location_employee_path(locations(:other), employees(:other_employee))
    assert_response :not_found
  end
end
