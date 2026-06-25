require "test_helper"

class ScheduleFlowTest < ActionDispatch::IntegrationTest
  test "a signed-in user can create a weekly schedule for their own location" do
    sign_in users(:manager)
    week_start = Date.new(2026, 6, 28)

    assert_difference -> { locations(:main).schedules.count }, 1 do
      post location_schedules_path(locations(:main)), params: {
        schedule: {
          week_start_date: week_start,
          notes: "Holiday week"
        }
      }
    end

    schedule = locations(:main).schedules.find_by!(week_start_date: week_start)
    assert_redirected_to location_schedule_path(locations(:main), schedule)
  end

  test "new schedule form renders sunday-start week options without a date field" do
    sign_in users(:manager)

    travel_to Date.new(2026, 7, 1) do
      get new_location_schedule_path(locations(:main))
    end

    assert_response :success
    assert_select "input[type=date][name='schedule[week_start_date]']", count: 0
    assert_select "select[name='schedule[week_start_date]']"
    assert_select "select[name='schedule[week_start_date]'] option[selected][value='2026-06-28']", text: "Week of Sunday, June 28"
    assert_select "select[name='schedule[week_start_date]'] option", text: "Week of Sunday, July 5"
    assert_select "select[name='schedule[source_schedule_id]'] option", text: "Blank schedule"
    assert_select "select[name='schedule[source_schedule_id]'] option", text: /Week of Sunday June 21 - 27/
  end

  test "new schedule form does not offer an existing schedule week" do
    sign_in users(:manager)

    travel_to Date.new(2026, 6, 25) do
      get new_location_schedule_path(locations(:main))
    end

    assert_response :success
    assert_select "select[name='schedule[week_start_date]'] option[value='2026-06-21']", count: 0
  end

  test "copy schedule link preselects the source schedule" do
    sign_in users(:manager)

    get new_location_schedule_path(locations(:main), copy_from_schedule_id: schedules(:main_week).id)

    assert_response :success
    assert_select "select[name='schedule[source_schedule_id]'] option[selected][value='#{schedules(:main_week).id}']"
  end

  test "create this week's schedule uses the current sunday" do
    sign_in users(:manager)

    travel_to Date.new(2026, 7, 1) do
      assert_difference -> { locations(:main).schedules.count }, 1 do
        post location_schedules_path(locations(:main))
      end
    end

    schedule = locations(:main).schedules.find_by!(week_start_date: Date.new(2026, 6, 28))
    assert_redirected_to location_schedule_path(locations(:main), schedule)
  end

  test "a user can create a new weekly schedule by copying an existing schedule" do
    sign_in users(:manager)

    assert_difference -> { locations(:main).schedules.count }, 1 do
      assert_difference -> { Shift.count }, 1 do
        post location_schedules_path(locations(:main)), params: {
          schedule: {
            week_start_date: "2026-06-28",
            source_schedule_id: schedules(:main_week).id,
            notes: "Copied forward"
          }
        }
      end
    end

    schedule = locations(:main).schedules.find_by!(week_start_date: Date.new(2026, 6, 28))
    copied_shift = schedule.shifts.find_by!(employee: employees(:sam), position: positions(:server))

    assert_equal Date.new(2026, 6, 29), copied_shift.shift_date
    assert_equal "16:00", copied_shift.starts_at.strftime("%H:%M")
    assert_equal "22:00", copied_shift.ends_at.strftime("%H:%M")
    assert_redirected_to location_schedule_path(locations(:main), schedule)
  end

  test "duplicate schedules for the same location and week are blocked" do
    sign_in users(:manager)

    assert_no_difference -> { locations(:main).schedules.count } do
      post location_schedules_path(locations(:main)), params: {
        schedule: {
          week_start_date: schedules(:main_week).week_start_date
        }
      }
    end

    assert_redirected_to location_schedule_path(locations(:main), schedules(:main_week))
  end

  test "a user cannot copy a schedule from another account" do
    sign_in users(:manager)

    assert_no_difference -> { locations(:main).schedules.count } do
      post location_schedules_path(locations(:main)), params: {
        schedule: {
          week_start_date: "2026-06-28",
          source_schedule_id: schedules(:other_week).id
        }
      }
    end

    assert_response :not_found
  end

  test "a user can delete their own schedule and its shifts" do
    sign_in users(:manager)
    schedule_id = schedules(:main_week).id
    shift_id = shifts(:sam_monday).id

    assert_difference -> { Schedule.count }, -1 do
      assert_difference -> { Shift.count }, -1 do
        delete location_schedule_path(locations(:main), schedules(:main_week))
      end
    end

    assert_redirected_to location_schedules_path(locations(:main))
    assert_nil Schedule.find_by(id: schedule_id)
    assert_nil Shift.find_by(id: shift_id)
  end

  test "the schedules list shows a delete button for each schedule" do
    sign_in users(:manager)

    get location_schedules_path(locations(:main))

    assert_response :success
    assert_select "form[action='#{location_schedule_path(locations(:main), schedules(:main_week))}'] button", text: "Delete"
  end

  test "a user cannot delete another account schedule" do
    sign_in users(:manager)

    assert_no_difference -> { Schedule.count } do
      delete location_schedule_path(locations(:other), schedules(:other_week))
    end

    assert_response :not_found
  end

  test "a user can create a shift from the employee view" do
    sign_in users(:manager)

    assert_difference -> { schedules(:main_week).shifts.count }, 1 do
      post location_schedule_shifts_path(locations(:main), schedules(:main_week), view: "employees", employee_id: employees(:sam).id), params: {
        shift: {
          employee_id: employees(:sam).id,
          position_id: positions(:server).id,
          shift_date: "2026-06-23",
          starts_at: "16:00",
          ends_at: "22:00"
        }
      }
    end

    assert_redirected_to location_schedule_path(locations(:main), schedules(:main_week), view: "employees")
  end

  test "new shift form renders half-hour time choices" do
    sign_in users(:manager)

    get new_location_schedule_shift_path(locations(:main), schedules(:main_week), employee_id: employees(:sam).id, shift_date: "2026-06-23")

    assert_response :success
    assert_select "input[type=time]", count: 0
    assert_select "select[name='shift[starts_at]']"
    assert_select "select[name='shift[ends_at]']"
    assert_select "select[name='shift[starts_at]'] option", text: "Select a time"
    assert_select "select[name='shift[starts_at]'] option[selected]", count: 0
    assert_select "select[name='shift[starts_at]'] option[value='07:00']", text: "7:00 AM"
    assert_select "select[name='shift[starts_at]'] option[value='23:30']", text: "11:30 PM"
  end

  test "edit shift form selects saved start and end times" do
    sign_in users(:manager)

    get edit_location_schedule_shift_path(locations(:main), schedules(:main_week), shifts(:sam_monday))

    assert_response :success
    assert_select "select[name='shift[starts_at]'] option[selected][value='16:00']", text: "4:00 PM"
    assert_select "select[name='shift[ends_at]'] option[selected][value='22:00']", text: "10:00 PM"
  end

  test "a user can create a shift from the position view" do
    sign_in users(:manager)

    assert_difference -> { schedules(:main_week).shifts.count }, 1 do
      post location_schedule_shifts_path(locations(:main), schedules(:main_week), view: "positions", position_id: positions(:server).id), params: {
        shift: {
          employee_id: employees(:sam).id,
          position_id: positions(:server).id,
          shift_date: "2026-06-24",
          starts_at: "16:00",
          ends_at: "22:00"
        }
      }
    end

    assert_redirected_to location_schedule_path(locations(:main), schedules(:main_week), view: "positions")
  end

  test "a half-hour time can be saved successfully" do
    sign_in users(:manager)

    assert_difference -> { schedules(:main_week).shifts.count }, 1 do
      post location_schedule_shifts_path(locations(:main), schedules(:main_week), view: "positions", position_id: positions(:server).id), params: {
        shift: {
          employee_id: employees(:sam).id,
          position_id: positions(:server).id,
          shift_date: "2026-06-26",
          starts_at: "16:30",
          ends_at: "22:30"
        }
      }
    end

    shift = schedules(:main_week).shifts.find_by!(shift_date: "2026-06-26")
    assert_equal "16:30", shift.starts_at.strftime("%H:%M")
    assert_equal "22:30", shift.ends_at.strftime("%H:%M")
  end

  test "a shift is rejected if the employee is not assigned to the chosen position" do
    sign_in users(:manager)

    assert_no_difference -> { schedules(:main_week).shifts.count } do
      post location_schedule_shifts_path(locations(:main), schedules(:main_week)), params: {
        shift: {
          employee_id: employees(:sam).id,
          position_id: positions(:bartender).id,
          shift_date: "2026-06-25",
          starts_at: "16:00",
          ends_at: "22:00"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "a schedule cannot save a shift when end time is not after start time" do
    sign_in users(:manager)

    assert_no_difference -> { schedules(:main_week).shifts.count } do
      post location_schedule_shifts_path(locations(:main), schedules(:main_week)), params: {
        shift: {
          employee_id: employees(:sam).id,
          position_id: positions(:server).id,
          shift_date: "2026-06-25",
          starts_at: "22:00",
          ends_at: "16:00"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".alert", text: /End time must be after the start time/
  end

  test "a shift is rejected if its date is outside the schedule week" do
    sign_in users(:manager)

    assert_no_difference -> { schedules(:main_week).shifts.count } do
      post location_schedule_shifts_path(locations(:main), schedules(:main_week)), params: {
        shift: {
          employee_id: employees(:sam).id,
          position_id: positions(:server).id,
          shift_date: "2026-06-28",
          starts_at: "16:00",
          ends_at: "22:00"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "a user cannot access schedules belonging to another account" do
    sign_in users(:manager)

    get location_schedule_path(locations(:other), schedules(:other_week))
    assert_response :not_found
  end

  test "a user can access the print page for their own schedule" do
    sign_in users(:manager)

    get print_location_schedule_path(locations(:main), schedules(:main_week), view: "positions")

    assert_response :success
    assert_select ".print-brand", text: "Hickory Clock"
  end

  test "a user cannot access another account schedule print page" do
    sign_in users(:manager)

    get print_location_schedule_path(locations(:other), schedules(:other_week), view: "positions")

    assert_response :not_found
  end

  test "current schedule route opens the current weekly schedule" do
    sign_in users(:manager)

    travel_to Date.new(2026, 6, 25) do
      get current_schedule_path
    end

    assert_redirected_to location_schedule_path(locations(:main), schedules(:main_week))
  end

  test "current schedule route preserves the selected view when opening the current weekly schedule" do
    sign_in users(:manager)

    travel_to Date.new(2026, 6, 25) do
      get current_schedule_path(view: "employees")
    end

    assert_redirected_to location_schedule_path(locations(:main), schedules(:main_week), view: "employees")
  end

  test "current schedule route falls back to the schedule list when the current week does not exist" do
    sign_in users(:manager)
    account = Account.create!(name: "Copy Grill")
    location = account.locations.create!(name: "Main Room")
    user = User.create!(
      first_name: "Casey",
      last_name: "Manager",
      email: "casey-manager@example.com",
      password: "password123",
      password_confirmation: "password123",
      account: account
    )
    sign_in user

    travel_to Date.new(2026, 6, 25) do
      get current_schedule_path
    end

    assert_redirected_to location_schedules_path(location)
    follow_redirect!
    assert_select ".alert", text: /No current weekly schedule yet/
  end

  test "a user cannot access shifts belonging to another account" do
    sign_in users(:manager)

    get edit_location_schedule_shift_path(locations(:other), schedules(:other_week), shifts(:other_monday))
    assert_response :not_found
  end

  test "employee and position views both render the same saved shift" do
    sign_in users(:manager)

    get location_schedule_path(locations(:main), schedules(:main_week), view: "employees")
    assert_response :success
    assert_select "table.schedule-table thead tr th:nth-child(2)", text: "Sun 21"
    assert_select ".shift-pill", text: /Server/
    assert_select ".shift-pill", text: /4:00-10:00 PM/
    assert_select ".shift-pill[style*='--position-color: #8A4F2A']"

    get location_schedule_path(locations(:main), schedules(:main_week), view: "positions")
    assert_response :success
    assert_select "table.schedule-table thead tr th:first-child", text: "Sun 21"
    assert_select ".position-heading-swatch[style*='--position-color: #8A4F2A']"
    assert_select ".shift-pill", text: /Sam Server/
    assert_select ".shift-pill", text: /4:00-10:00 PM/
    assert_select ".shift-pill[style*='--position-color: #8A4F2A']"
  end

  test "printing from position view renders position print heading and saved shift" do
    sign_in users(:manager)

    get print_location_schedule_path(locations(:main), schedules(:main_week), view: "positions")

    assert_response :success
    assert_select ".print-meta strong", text: "Schedule by Position"
    assert_select ".print-position-section h2", text: "Servers"
    assert_select ".print-shift-line", text: /Sam Server/
    assert_select ".print-shift-line", text: /4:00-10:00 PM/
  end

  test "printing from employee view renders employee print heading and saved shift" do
    sign_in users(:manager)

    get print_location_schedule_path(locations(:main), schedules(:main_week), view: "employees")

    assert_response :success
    assert_select ".print-meta strong", text: "Schedule by Employee"
    assert_select "table.print-employee-table tbody th", text: "Sam Server"
    assert_select ".print-shift-line", text: /Server/
    assert_select ".print-shift-line", text: /4:00-10:00 PM/
  end

  test "print page includes account location and sunday through saturday date range" do
    sign_in users(:manager)

    get print_location_schedule_path(locations(:main), schedules(:main_week), view: "positions")

    assert_response :success
    assert_select ".print-header h1", text: "Hickory Grill"
    assert_select ".print-header p", text: "Downtown"
    assert_select ".print-meta", text: /Week of June 21-27, 2026/
    assert_select ".print-day-block h3:first-child", text: "Sunday"
    assert_select ".print-day-block h3", text: "Saturday"
  end

  test "print page omits normal navigation and includes utility controls" do
    sign_in users(:manager)

    get print_location_schedule_path(locations(:main), schedules(:main_week), view: "employees")

    assert_response :success
    assert_select "nav", count: 0
    assert_select ".print-toolbar.screen-only button", text: "Print"
    assert_select ".print-toolbar.screen-only a[href='#{location_schedule_path(locations(:main), schedules(:main_week), view: "employees")}']", text: "Back to Schedule"
  end

  test "regular schedule page includes a visible print schedule action" do
    sign_in users(:manager)

    get location_schedule_path(locations(:main), schedules(:main_week), view: "employees")

    assert_response :success
    assert_select "a[href='#{print_location_schedule_path(locations(:main), schedules(:main_week), view: "employees")}'][target='_blank']", text: "Print Schedule"
  end

  test "regular schedule page includes a visible copy schedule action" do
    sign_in users(:manager)

    get location_schedule_path(locations(:main), schedules(:main_week), view: "employees")

    assert_response :success
    assert_select "a[href='#{new_location_schedule_path(locations(:main), copy_from_schedule_id: schedules(:main_week).id)}']", text: "Copy Schedule"
  end

  test "schedule show page contains a visible manage schedule action" do
    sign_in users(:manager)

    get location_schedule_path(locations(:main), schedules(:main_week))

    assert_response :success
    assert_select "h1", "Week of Sunday June 21 - 27"
    assert_select "a[href='#{edit_location_schedule_path(locations(:main), schedules(:main_week))}']", text: "Manage Schedule"
  end

  test "schedule management page allows notes to be updated" do
    sign_in users(:manager)

    patch location_schedule_path(locations(:main), schedules(:main_week)), params: {
      schedule: {
        notes: "Updated manager notes"
      }
    }

    assert_redirected_to location_schedule_path(locations(:main), schedules(:main_week))
    assert_equal "Updated manager notes", schedules(:main_week).reload.notes
  end

  test "schedule management page keeps delete action visible" do
    sign_in users(:manager)

    get edit_location_schedule_path(locations(:main), schedules(:main_week))

    assert_response :success
    assert_select "textarea[name='schedule[notes]']"
    assert_select "a", text: "Return to Weekly Schedule"
    assert_select "button", text: "Delete Schedule"
    assert_select "form[onsubmit*='permanently delete all shifts']"
  end

  test "opening a schedule without a view parameter defaults to position view" do
    sign_in users(:manager)

    get location_schedule_path(locations(:main), schedules(:main_week))

    assert_response :success
    assert_select ".btn.btn-primary", text: "Positions"
    assert_select "table.schedule-table thead tr th:first-child", text: "Sun 21"
    assert_select ".shift-pill", text: /Sam Server/
  end

  test "opening a schedule with employee view parameter renders employee view" do
    sign_in users(:manager)

    get location_schedule_path(locations(:main), schedules(:main_week), view: "employees")

    assert_response :success
    assert_select ".btn.btn-primary", text: "Employees"
    assert_select "table.schedule-table thead tr th:nth-child(2)", text: "Sun 21"
    assert_select ".schedule-name-column", text: /Sam Server/
  end

  test "non-current schedule page includes a current schedule button" do
    sign_in users(:manager)
    older_schedule = locations(:main).schedules.create!(week_start_date: Date.new(2026, 6, 14), status: "draft")

    travel_to Date.new(2026, 6, 25) do
      get location_schedule_path(locations(:main), older_schedule, view: "employees")
    end

    assert_response :success
    assert_select "a[href='#{current_schedule_path(view: "employees")}']", text: "Current Schedule"
  end
end
