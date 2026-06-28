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
    assert_select "select[name='schedule[source_schedule_id]'] option", text: /Week of Sunday June 21/
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

  test "new schedule form honors a selected week start" do
    sign_in users(:manager)

    get new_location_schedule_path(locations(:main), week_start_date: "2026-06-28")

    assert_response :success
    assert_select "select[name='schedule[week_start_date]'] option[selected][value='2026-06-28']"
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

  test "schedule list uses the sunday start date label" do
    sign_in users(:manager)
    locations(:main).schedules.create!(week_start_date: Date.new(2026, 6, 28), status: "draft")

    get location_schedules_path(locations(:main))

    assert_response :success
    assert_select "td.fw-medium", text: /Week of Sunday June 28/
    assert_select "td.fw-medium", text: /July/, count: 0
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

    assert_redirected_to location_schedule_path(locations(:main), schedules(:main_week), view: "employees", section: "foh")
  end

  test "a user can move their own shift to another date in the same schedule week" do
    sign_in users(:manager)
    shift = shifts(:sam_monday)
    shift.update!(notes: "Patio section")

    patch move_location_schedule_shift_path(locations(:main), schedules(:main_week), shift, view: "employees", section: "foh"),
      params: { shift: { shift_date: "2026-06-25" } },
      as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "move", payload["action"]
    assert_equal shift.id, payload["shift_id"]
    assert_equal "2026-06-25", payload["shift_date"]
    assert_includes payload["shift_html"], "data-shift-id=\"#{shift.id}\""
    assert_includes payload["shift_html"], "data-shift-date=\"2026-06-25\""
    assert_equal location_schedule_path(locations(:main), schedules(:main_week), view: "employees", section: "foh"), payload["redirect_url"]

    shift.reload
    assert_equal Date.new(2026, 6, 25), shift.shift_date
    assert_equal employees(:sam), shift.employee
    assert_equal positions(:server), shift.position
    assert_equal "16:00", shift.starts_at.strftime("%H:%M")
    assert_equal "22:00", shift.ends_at.strftime("%H:%M")
    assert_equal "Patio section", shift.notes
  end

  test "moving a shift outside the schedule week is rejected" do
    sign_in users(:manager)
    shift = shifts(:sam_monday)
    original_date = shift.shift_date

    patch move_location_schedule_shift_path(locations(:main), schedules(:main_week), shift),
      params: { shift: { shift_date: "2026-06-28" } },
      as: :json

    assert_response :unprocessable_entity
    assert_equal original_date, shift.reload.shift_date
  end

  test "a user cannot move another account shift" do
    sign_in users(:manager)

    patch move_location_schedule_shift_path(locations(:other), schedules(:other_week), shifts(:other_monday)),
      params: { shift: { shift_date: "2026-06-25" } },
      as: :json

    assert_response :not_found
  end

  test "a user can copy their own shift to another date in the same schedule week" do
    sign_in users(:manager)
    shift = shifts(:sam_monday)
    shift.update!(notes: "Patio section")

    assert_difference -> { schedules(:main_week).shifts.count }, 1 do
      post copy_location_schedule_shift_path(locations(:main), schedules(:main_week), shift, view: "positions", section: "foh"),
        params: { shift: { shift_date: "2026-06-25" } },
        as: :json
    end

    assert_response :success
    payload = JSON.parse(response.body)

    shift.reload
    copied_shift = schedules(:main_week).shifts.where.not(id: shift.id).find_by!(shift_date: Date.new(2026, 6, 25))
    assert_equal "copy", payload["action"]
    assert_equal copied_shift.id, payload["shift_id"]
    assert_equal "2026-06-25", payload["shift_date"]
    assert_includes payload["shift_html"], "data-shift-id=\"#{copied_shift.id}\""
    assert_includes payload["shift_html"], "data-shift-date=\"2026-06-25\""
    assert_equal location_schedule_path(locations(:main), schedules(:main_week), view: "positions", section: "foh"), payload["redirect_url"]
    assert_equal Date.new(2026, 6, 22), shift.shift_date
    assert_equal shift.employee, copied_shift.employee
    assert_equal shift.position, copied_shift.position
    assert_equal "16:00", copied_shift.starts_at.strftime("%H:%M")
    assert_equal "22:00", copied_shift.ends_at.strftime("%H:%M")
    assert_equal "Patio section", copied_shift.notes
  end

  test "copying a shift to its original date is rejected" do
    sign_in users(:manager)

    assert_no_difference -> { schedules(:main_week).shifts.count } do
      post copy_location_schedule_shift_path(locations(:main), schedules(:main_week), shifts(:sam_monday)),
        params: { shift: { shift_date: shifts(:sam_monday).shift_date.iso8601 } },
        as: :json
    end

    assert_response :unprocessable_entity
  end

  test "copying a shift outside the schedule week is rejected" do
    sign_in users(:manager)

    assert_no_difference -> { schedules(:main_week).shifts.count } do
      post copy_location_schedule_shift_path(locations(:main), schedules(:main_week), shifts(:sam_monday)),
        params: { shift: { shift_date: "2026-06-28" } },
        as: :json
    end

    assert_response :unprocessable_entity
  end

  test "a user cannot copy another account shift" do
    sign_in users(:manager)

    assert_no_difference -> { Shift.count } do
      post copy_location_schedule_shift_path(locations(:other), schedules(:other_week), shifts(:other_monday)),
        params: { shift: { shift_date: "2026-06-25" } },
        as: :json
    end

    assert_response :not_found
  end

  test "employee view shift pills include an inline delete button" do
    sign_in users(:manager)

    get location_schedule_path(locations(:main), schedules(:main_week), view: "employees")

    assert_response :success
    assert_select "form.shift-pill-delete-form[action='#{location_schedule_shift_path(locations(:main), schedules(:main_week), shifts(:sam_monday), view: "employees", section: "foh")}'] button.shift-pill-delete"
    assert_select ".shift-pill-delete span[aria-hidden='true']", text: "×"
    assert_select ".shift-pill[draggable='true'][data-shift-id='#{shifts(:sam_monday).id}'][data-move-url='#{move_location_schedule_shift_path(locations(:main), schedules(:main_week), shifts(:sam_monday), view: "employees", section: "foh")}'][data-copy-url='#{copy_location_schedule_shift_path(locations(:main), schedules(:main_week), shifts(:sam_monday), view: "employees", section: "foh")}']"
    assert_select ".shift-pill[data-action*='pointerdown->schedule-quick-edit#optionPointerDown']"
    assert_select ".shift-pill-title-link[draggable='false'][data-action='click->schedule-quick-edit#rememberScheduleViewport'][data-return-url='#{location_schedule_path(locations(:main), schedules(:main_week), view: "employees", section: "foh")}']"
    assert_select ".shift-pill-secondary-link[draggable='false'][data-action='click->schedule-quick-edit#rememberScheduleViewport'][data-return-url='#{location_schedule_path(locations(:main), schedules(:main_week), view: "employees", section: "foh")}']"
    assert_select ".shift-pill-time-link[draggable='false'][data-action='click->schedule-quick-edit#rememberScheduleViewport'][data-return-url='#{location_schedule_path(locations(:main), schedules(:main_week), view: "employees", section: "foh")}']"
    assert_select ".schedule-quick-edit-message[data-schedule-quick-edit-target='alert']"
    assert_select "td.schedule-cell-has-shift[style*='--position-color: #{positions(:server).display_color}'][data-schedule-quick-edit-target='cell'][data-view-mode='employees'][data-employee-id='#{employees(:sam).id}'][data-shift-date='2026-06-22']"
    assert_select "a.schedule-add-link[href='#{new_location_schedule_shift_path(locations(:main), schedules(:main_week), employee_id: employees(:sam).id, shift_date: "2026-06-23", view: "employees", section: "foh")}'] .schedule-add-link-context", text: "Sam Server"
    assert_select "a.schedule-add-link[href='#{new_location_schedule_shift_path(locations(:main), schedules(:main_week), employee_id: employees(:sam).id, shift_date: "2026-06-23", view: "employees", section: "foh")}'] .schedule-add-link-label", text: "+ Add Shift"
  end

  test "position view shift pills include an inline delete button" do
    sign_in users(:manager)

    get location_schedule_path(locations(:main), schedules(:main_week), view: "positions")

    assert_response :success
    assert_select "form.shift-pill-delete-form[action='#{location_schedule_shift_path(locations(:main), schedules(:main_week), shifts(:sam_monday), view: "positions", section: "foh")}'] button.shift-pill-delete"
    assert_select ".shift-pill-delete span[aria-hidden='true']", text: "×", minimum: 1
    assert_select "td[data-schedule-quick-edit-target='cell'][data-view-mode='positions'][data-position-id='#{positions(:server).id}'][data-shift-date='2026-06-23']"
    assert_select "a.schedule-add-link[href='#{new_location_schedule_shift_path(locations(:main), schedules(:main_week), position_id: positions(:server).id, shift_date: "2026-06-23", view: "positions", section: "foh")}'] .schedule-add-link-context", count: 0
    assert_select "a.schedule-add-link[href='#{new_location_schedule_shift_path(locations(:main), schedules(:main_week), position_id: positions(:server).id, shift_date: "2026-06-23", view: "positions", section: "foh")}'] .schedule-add-link-label", text: "+ Add Server"
  end

  test "a user can delete a shift from the position view and return to the calendar" do
    sign_in users(:manager)

    assert_difference -> { schedules(:main_week).shifts.count }, -1 do
      delete location_schedule_shift_path(locations(:main), schedules(:main_week), shifts(:sam_monday), view: "positions", section: "foh")
    end

    assert_redirected_to location_schedule_path(locations(:main), schedules(:main_week), view: "positions", section: "foh")
  end

  test "a user can delete a shift from the employee view and return to the calendar" do
    sign_in users(:manager)

    assert_difference -> { schedules(:main_week).shifts.count }, -1 do
      delete location_schedule_shift_path(locations(:main), schedules(:main_week), shifts(:sam_monday), view: "employees", section: "foh")
    end

    assert_redirected_to location_schedule_path(locations(:main), schedules(:main_week), view: "employees", section: "foh")
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

  test "edit shift form limits position choices to the employee assignments" do
    sign_in users(:manager)

    get edit_location_schedule_shift_path(locations(:main), schedules(:main_week), shifts(:sam_monday))

    assert_response :success
    assert_select "select[name='shift[position_id]'] option", text: "Server"
    assert_select "select[name='shift[position_id]'] option", text: "Bartender", count: 0
  end

  test "edit shift form preserves an existing override position choice" do
    sign_in users(:manager)
    override_shift = schedules(:main_week).shifts.create!(
      employee: employees(:sam),
      position: positions(:server),
      shift_date: Date.new(2026, 6, 23),
      starts_at: "16:00",
      ends_at: "22:00"
    )
    override_shift.update_columns(position_id: positions(:bartender).id)

    get edit_location_schedule_shift_path(locations(:main), schedules(:main_week), override_shift)

    assert_response :success
    assert_select "select[name='shift[position_id]'] option", text: "Server"
    assert_select "select[name='shift[position_id]'] option[selected][value='#{positions(:bartender).id}']", text: "Bartender"
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

    assert_redirected_to location_schedule_path(locations(:main), schedules(:main_week), view: "positions", section: "foh")
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
    assert_select ".form-error-messages", text: /End time must be after the start time/
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
    assert_select ".print-brand", text: "Schedule"
  end

  test "a user cannot access another account schedule print page" do
    sign_in users(:manager)

    get print_location_schedule_path(locations(:other), schedules(:other_week), view: "positions")

    assert_response :not_found
  end

  test "current schedule route opens the current weekly schedule when no schedule has been remembered" do
    sign_in users(:manager)

    travel_to Date.new(2026, 6, 25) do
      get current_schedule_path
    end

    assert_redirected_to location_schedule_path(locations(:main), schedules(:main_week), view: "positions", section: "foh")
  end

  test "current schedule route preserves the selected view when opening the current weekly schedule" do
    sign_in users(:manager)

    travel_to Date.new(2026, 6, 25) do
      get current_schedule_path(view: "employees")
    end

    assert_redirected_to location_schedule_path(locations(:main), schedules(:main_week), view: "employees", section: "foh")
  end

  test "current schedule route preserves the both view when opening the current weekly schedule" do
    sign_in users(:manager)

    travel_to Date.new(2026, 6, 25) do
      get current_schedule_path(view: "both")
    end

    assert_redirected_to location_schedule_path(locations(:main), schedules(:main_week), view: "both", section: "foh")
  end

  test "current schedule route preserves the selected section from the session" do
    sign_in users(:manager)

    get location_schedule_path(locations(:main), schedules(:main_week), section: "all")

    travel_to Date.new(2026, 6, 25) do
      get current_schedule_path
    end

    assert_redirected_to location_schedule_path(locations(:main), schedules(:main_week), view: "positions", section: "all")
  end

  test "current schedule route opens the last schedule the user worked on" do
    sign_in users(:manager)
    older_schedule = locations(:main).schedules.create!(week_start_date: Date.new(2026, 6, 14), status: "draft")

    get location_schedule_path(locations(:main), older_schedule, view: "employees", section: "all")
    get current_schedule_path

    assert_redirected_to location_schedule_path(locations(:main), older_schedule, view: "employees", section: "all")
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
    assert_select ".form-error-messages", count: 0
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
    assert_select "table.schedule-table thead tr th:first-child", text: "Sun 21"
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

  test "employee schedules list employees in first-name order" do
    sign_in users(:manager)
    employee = locations(:main).employees.create!(
      first_name: "Alex",
      last_name: "Zed",
      email: "alex-schedule@example.com"
    )
    employee.positions << positions(:server)

    get location_schedule_path(locations(:main), schedules(:main_week), view: "employees")

    assert_response :success
    alex_index = response.body.index(%(data-employee-id="#{employee.id}"))
    sam_index = response.body.index(%(data-employee-id="#{employees(:sam).id}"))

    assert_not_nil alex_index
    assert_not_nil sam_index
    assert_operator alex_index, :<, sam_index
  end

  test "position schedules follow the saved position order" do
    sign_in users(:manager)
    positions(:bartender).insert_at!(1)

    get location_schedule_path(locations(:main), schedules(:main_week), view: "positions", section: "foh")

    assert_response :success
    assert_match(/Bartender.*Server/m, response.body)
  end

  test "printing from position view renders position print heading and saved shift" do
    sign_in users(:manager)

    get print_location_schedule_path(locations(:main), schedules(:main_week), view: "positions")

    assert_response :success
    assert_select ".print-meta strong", text: "Schedule by Position"
    assert_select ".print-position-section[style*='--print-position-color'] h2", text: "Servers"
    assert_select ".print-shift-line", text: /Sam Server/
    assert_select ".print-shift-line", text: /4:00-10:00 PM/
  end

  test "printing can be scoped to back of house or front of house" do
    sign_in users(:manager)
    boh_position = locations(:main).positions.create!(name: "Prep Cook", section: "boh", color: Position::COLOR_PALETTE.first)
    employees(:sam).positions << boh_position unless employees(:sam).positions.exists?(boh_position.id)
    schedules(:main_week).shifts.create!(
      employee: employees(:sam),
      position: boh_position,
      shift_date: Date.new(2026, 6, 22),
      starts_at: "09:00",
      ends_at: "15:00"
    )

    get print_location_schedule_path(locations(:main), schedules(:main_week), view: "positions", section: "boh")

    assert_response :success
    assert_select ".print-meta", text: /Back of House/
    assert_select ".print-position-section h2", text: "Prep Cooks"
    assert_select ".print-shift-line", text: /Sam Server/
    assert_select ".print-shift-line", text: /9:00 AM-3:00 PM/
    assert_select ".print-position-section h2", text: "Servers", count: 0

    get print_location_schedule_path(locations(:main), schedules(:main_week), view: "positions", section: "foh")

    assert_response :success
    assert_select ".print-meta", text: /Front of House/
    assert_select ".print-position-section h2", text: "Servers"
    assert_select ".print-position-section h2", text: "Prep Cooks", count: 0
  end

  test "printing from employee view renders employee print heading and saved shift" do
    sign_in users(:manager)

    get print_location_schedule_path(locations(:main), schedules(:main_week), view: "employees")

    assert_response :success
    assert_select ".print-meta strong", text: "Schedule by Employee"
    assert_select "table.print-employee-table tbody th", text: "Sam Server"
    assert_select ".print-shift-line", text: /Server/
    assert_select ".print-shift-line", text: /4:00-10:00 PM/
    assert_select ".print-off", count: 0
  end

  test "printing from both view renders position and employee grouping" do
    sign_in users(:manager)

    get print_location_schedule_path(locations(:main), schedules(:main_week), view: "both")

    assert_response :success
    assert_select ".print-meta strong", text: "Schedule by Position and Employee"
    assert_select ".print-position-section[style*='--print-position-color'] h2", text: "Servers"
    assert_select "table.print-employee-table tbody th", text: "Sam Server"
    assert_select ".print-shift-line", text: /4:00-10:00 PM/
    assert_select ".print-off", count: 0
  end

  test "print page includes account location and sunday start label" do
    sign_in users(:manager)

    get print_location_schedule_path(locations(:main), schedules(:main_week), view: "positions")

    assert_response :success
    assert_select ".print-header h1", text: "Hickory Grill"
    assert_select ".print-header p", text: "Downtown"
    assert_select ".print-meta", text: /Week of Sunday June 21, 2026/
    assert_select ".print-day-block h3:first-child", text: "SUN 21"
    assert_select ".print-day-block h3", text: "SAT 27"
  end

  test "print page for a cross-month week uses the sunday start label" do
    sign_in users(:manager)
    cross_month_schedule = locations(:main).schedules.create!(week_start_date: Date.new(2026, 6, 28), status: "draft")

    get print_location_schedule_path(locations(:main), cross_month_schedule, view: "positions")

    assert_response :success
    assert_select ".print-meta", text: /Week of Sunday June 28, 2026/
    assert_select ".print-meta", text: /July/, count: 0
  end

  test "print page omits normal navigation and includes utility controls" do
    sign_in users(:manager)

    get print_location_schedule_path(locations(:main), schedules(:main_week), view: "employees")

    assert_response :success
    assert_select "nav", count: 0
    assert_select ".print-toolbar.screen-only button", text: "Print"
    assert_select ".print-toolbar.screen-only a[href='#{location_schedule_path(locations(:main), schedules(:main_week), view: "employees", section: "foh")}']", text: "Back to Schedule"
  end

  test "regular schedule page includes a visible print schedule action" do
    sign_in users(:manager)

    get location_schedule_path(locations(:main), schedules(:main_week), view: "employees")

    assert_response :success
    assert_select ".schedule-schedule-actions a[href='#{print_location_schedule_path(locations(:main), schedules(:main_week), view: "employees", section: "foh")}'][target='_blank']", text: "Print Schedule"
  end

  test "regular schedule page includes a visible copy schedule action" do
    sign_in users(:manager)

    get location_schedule_path(locations(:main), schedules(:main_week), view: "employees")

    assert_response :success
    assert_select ".schedule-schedule-actions a[href='#{new_location_schedule_path(locations(:main), copy_from_schedule_id: schedules(:main_week).id)}']", text: "Copy Schedule"
  end

  test "schedule show page contains visible schedule actions" do
    sign_in users(:manager)

    get location_schedule_path(locations(:main), schedules(:main_week))

    assert_response :success
    assert_select ".schedule-schedule-controls .btn-group", count: 2
    assert_select ".schedule-schedule-controls .btn-group[aria-label='Schedule view'] .btn.btn-primary", text: "Positions"
    assert_select ".schedule-schedule-controls .btn-group[aria-label='Schedule section'] .btn.btn-primary", text: "FOH"
    assert_select ".schedule-schedule-actions", count: 1
    assert_select ".schedule-schedule-actions a[href='#{new_location_schedule_path(locations(:main), copy_from_schedule_id: schedules(:main_week).id)}']", text: "Copy Schedule"
    assert_select ".schedule-schedule-actions a[href='#{print_location_schedule_path(locations(:main), schedules(:main_week), view: "positions", section: "foh")}'][target='_blank']", text: "Print Schedule"
    assert_select ".schedule-week-title", count: 1
    assert_select ".schedule-week-title .schedule-hero-date-prefix", text: "Week of"
    assert_select ".schedule-week-title .schedule-hero-date-month", text: schedules(:main_week).week_start_date.strftime("%b").upcase
    assert_select ".schedule-week-title .schedule-hero-date-day", text: schedules(:main_week).week_start_date.day.to_s
    assert_select ".schedule-mini-month-nav a[aria-label='Last Month'][data-bs-toggle='tooltip'][data-bs-title='Last Month']", count: 1
    assert_select ".schedule-mini-month-nav a[aria-label='Current Schedule'][data-bs-toggle='tooltip'][data-bs-title='Current Schedule']", count: 1
    assert_select ".schedule-mini-month-nav a[aria-label='Today'][data-bs-toggle='tooltip'][data-bs-title='Today']", count: 1
    assert_select ".schedule-mini-month-nav a[aria-label='Next Month'][data-bs-toggle='tooltip'][data-bs-title='Next Month']", count: 1
    assert_select ".schedule-mini-month-control", count: 4
    assert_select ".schedule-mini-month-control .btn-call-to-action-primary", count: 2
    assert_select ".schedule-mini-month-control .btn-call-to-action-view.current-menu-toggle", count: 1
    assert_select ".schedule-mini-month-control .btn-call-to-action", count: 1
    assert_select ".schedule-mini-month-control .fa-solid", count: 4
    assert_select ".schedule-mini-month-control .bi", count: 0
    assert_select ".schedule-mini-month-nav .cta-label", text: "PREV"
    assert_select ".schedule-mini-month-nav .cta-label", text: "CURRENT"
    assert_select ".schedule-mini-month-nav .cta-label", text: "TODAY"
    assert_select ".schedule-mini-month-nav .cta-label", text: "NEXT"
    assert_select ".schedule-mini-month-title", text: "June 2026"
    assert_select ".schedule-mini-month-weekdays span", count: 7
    assert_select ".schedule-mini-month-day.is-in-schedule-week", count: 7
    assert_select ".schedule-mini-month-day.has-schedule", count: 7
    assert_select "a.schedule-mini-month-day[data-action='click->schedule-quick-edit#rememberMiniCalendarViewport'][href='#{location_schedule_path(locations(:main), schedules(:main_week), view: "positions", section: "foh")}']", text: "21"
    assert_select "a.schedule-mini-month-day[data-action='click->schedule-quick-edit#rememberMiniCalendarViewport'][href='#{new_location_schedule_path(locations(:main), week_start_date: "2026-06-28", view: "positions", section: "foh")}']", text: "28"
  end

  test "schedule show page highlights today in the header cards and calendar column" do
    sign_in users(:manager)

    travel_to Date.new(2026, 6, 25) do
      get location_schedule_path(locations(:main), schedules(:main_week))
    end

    assert_response :success
    assert_select "th.schedule-today-column", text: "Thu 25"
    assert_select "td.schedule-today-column", minimum: 1
  end

  test "schedule show page uses eastern time when highlighting today near midnight utc" do
    sign_in users(:manager)

    travel_to Time.utc(2026, 6, 27, 0, 30, 0) do
      get location_schedule_path(locations(:main), schedules(:main_week))
    end

    assert_response :success
    assert_select "th.schedule-today-column", text: "Fri 26"
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

  test "all divisions view shows both foh and boh positions and persists in the session" do
    sign_in users(:manager)
    boh_position = locations(:main).positions.create!(name: "Prep Cook", section: "boh", color: Position::COLOR_PALETTE.first)
    employees(:sam).positions << boh_position unless employees(:sam).positions.exists?(boh_position.id)
    schedules(:main_week).shifts.create!(
      employee: employees(:sam),
      position: boh_position,
      shift_date: Date.new(2026, 6, 22),
      starts_at: "09:00",
      ends_at: "15:00"
    )

    get location_schedule_path(locations(:main), schedules(:main_week), view: "positions", section: "all")

    assert_response :success
    assert_select ".schedule-schedule-controls .btn-group[aria-label='Schedule section'] .btn.btn-primary", text: "Both"
    assert_select ".schedule-section-display", count: 0
    assert_select ".card-header h2", text: /Server/
    assert_select ".card-header h2", text: /Prep Cook/

    get location_schedule_path(locations(:main), schedules(:main_week), view: "positions")

    assert_response :success
    assert_select ".schedule-schedule-controls .btn-group[aria-label='Schedule section'] .btn.btn-primary", text: "Both"
    assert_select ".schedule-section-display", count: 0
    assert_select ".card-header h2", text: /Prep Cook/
  end

  test "opening a schedule with employee view parameter renders employee view" do
    sign_in users(:manager)

    get location_schedule_path(locations(:main), schedules(:main_week), view: "employees")

    assert_response :success
    assert_select ".schedule-schedule-controls .btn-group[aria-label='Schedule view'] .btn.btn-primary", text: "Employees"
    assert_select "table.schedule-table thead tr th:first-child", text: "Sun 21"
    assert_select ".shift-pill", text: /Sam Server/
    assert_select ".shift-pill-employee-view .shift-pill-secondary", text: "Server"
  end

  test "opening a schedule with both view parameter renders positions grouped by employee" do
    sign_in users(:manager)

    get location_schedule_path(locations(:main), schedules(:main_week), view: "both")

    assert_response :success
    assert_select ".schedule-schedule-controls .btn-group[aria-label='Schedule view'] .btn.btn-primary", text: "Both"
    assert_select ".card-header h2", text: /Server/
    assert_select "table.schedule-table thead tr th:first-child", text: "Sun 21"
    assert_select ".shift-pill", text: /Sam Server/
    assert_select ".shift-pill", text: /4:00-10:00 PM/
    assert_select "td[data-schedule-quick-edit-target='cell'][data-view-mode='both'][data-employee-id='#{employees(:sam).id}'][data-position-id='#{positions(:server).id}'][data-shift-date='2026-06-23']"
    assert_select "a.schedule-add-link[href='#{new_location_schedule_shift_path(locations(:main), schedules(:main_week), employee_id: employees(:sam).id, position_id: positions(:server).id, shift_date: "2026-06-23", view: "both", section: "foh")}'] .schedule-add-link-context", text: "Sam Server"
    assert_select "a.schedule-add-link[href='#{new_location_schedule_shift_path(locations(:main), schedules(:main_week), employee_id: employees(:sam).id, position_id: positions(:server).id, shift_date: "2026-06-23", view: "both", section: "foh")}'] .schedule-add-link-label", text: "+ Add Shift"
  end

  test "all section uses the putty body background class" do
    sign_in users(:manager)

    get location_schedule_path(locations(:main), schedules(:main_week), view: "both", section: "all")

    assert_response :success
    assert_select "body.app-background-section-all", count: 1
  end

  test "boh and foh schedule views stay separated" do
    sign_in users(:manager)
    boh_position = locations(:main).positions.create!(name: "Prep Cook", section: "boh", color: Position::COLOR_PALETTE.first)
    employees(:sam).positions << boh_position unless employees(:sam).positions.exists?(boh_position.id)
    schedules(:main_week).shifts.create!(
      employee: employees(:sam),
      position: boh_position,
      shift_date: Date.new(2026, 6, 22),
      starts_at: "09:00",
      ends_at: "15:00"
    )

    get location_schedule_path(locations(:main), schedules(:main_week), view: "positions", section: "boh")

    assert_response :success
    assert_select ".schedule-section-display", text: "BOH"
    assert_select ".badge", text: "Back of House", count: 0
    assert_select ".badge", text: "Draft", count: 0
    assert_select ".badge", text: "Current Week", count: 0
    assert_select ".card-header h2", text: /Prep Cook/
    assert_select ".shift-pill", text: /9:00 AM-3:00 PM/
    assert_select ".shift-pill", text: /Bartender/, count: 0

    get location_schedule_path(locations(:main), schedules(:main_week), view: "positions", section: "foh")

    assert_response :success
    assert_select ".schedule-section-display", text: "FOH"
    assert_select ".badge", text: "Front of House", count: 0
    assert_select ".shift-pill", text: /Sam Server/
    assert_select ".shift-pill", text: /Prep Cook/, count: 0
  end

  test "non-current schedule page includes a current schedule button" do
    sign_in users(:manager)
    older_schedule = locations(:main).schedules.create!(week_start_date: Date.new(2026, 6, 14), status: "draft")

    travel_to Date.new(2026, 6, 25) do
      get location_schedule_path(locations(:main), older_schedule, view: "employees")
    end

    assert_response :success
    assert_select "a[href='#{current_schedule_path(view: "employees", section: "foh")}'][aria-label='Current Schedule']", count: 1
  end
end
