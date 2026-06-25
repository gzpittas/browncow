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
  end

  test "new schedule form does not offer an existing schedule week" do
    sign_in users(:manager)

    travel_to Date.new(2026, 6, 25) do
      get new_location_schedule_path(locations(:main))
    end

    assert_response :success
    assert_select "select[name='schedule[week_start_date]'] option[value='2026-06-21']", count: 0
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
    assert_select "select[name='shift[starts_at]'] option[value='00:00']", text: "12:00 AM"
    assert_select "select[name='shift[starts_at]'] option[value='00:30']", text: "12:30 AM"
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

    get location_schedule_path(locations(:main), schedules(:main_week), view: "positions")
    assert_response :success
    assert_select "table.schedule-table thead tr th:first-child", text: "Sun 21"
    assert_select ".shift-pill", text: /Sam Server/
    assert_select ".shift-pill", text: /4:00-10:00 PM/
  end

  test "schedule show page contains a visible manage schedule action" do
    sign_in users(:manager)

    get location_schedule_path(locations(:main), schedules(:main_week))

    assert_response :success
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
end
