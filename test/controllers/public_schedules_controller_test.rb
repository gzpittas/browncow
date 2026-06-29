require "test_helper"

class PublicSchedulesControllerTest < ActionDispatch::IntegrationTest
  test "disabled public schedule links are not available" do
    accounts(:main).update!(public_schedule_slug: "athens")

    get public_schedule_path("athens")

    assert_response :not_found
  end

  test "public schedule requires the shared password" do
    enable_public_schedule!

    travel_to Date.new(2026, 6, 25) do
      get public_schedule_path("athens")
    end

    assert_response :success
    assert_select "form[action='#{unlock_public_schedule_path("athens")}']"
    assert_select "input[type=password][name='password']"
    assert_select ".shift-pill", count: 0
  end

  test "public schedule unlocks and renders read only current schedule" do
    enable_public_schedule!

    travel_to Date.new(2026, 6, 25) do
      post unlock_public_schedule_path("athens"), params: { password: "staff-only" }
      assert_redirected_to public_schedule_path("athens")

      get public_schedule_path("athens", view: "positions", section: "foh")
    end

    assert_response :success
    assert_select "nav", count: 0
    assert_select "a[href='#{new_user_session_path}']", count: 0
    assert_select ".btn-group[aria-label='Schedule view'] a", text: "Positions"
    assert_select ".btn-group[aria-label='Schedule section'] a", text: "FOH"
    assert_select ".shift-pill", text: /Sam Server/
    assert_select ".shift-pill", text: /4:00-10:00 PM/
    assert_select "a[href*='/shifts/new']", count: 0
    assert_select "form[action*='/shifts/']", count: 0
  end

  test "public schedule exposes next week only when it exists" do
    enable_public_schedule!
    next_schedule = locations(:main).schedules.create!(week_start_date: Date.new(2026, 6, 28), status: "draft")
    next_schedule.shifts.create!(
      employee: employees(:sam),
      position: positions(:server),
      shift_date: Date.new(2026, 6, 29),
      starts_at: "12:00",
      ends_at: "18:00"
    )

    travel_to Date.new(2026, 6, 25) do
      post unlock_public_schedule_path("athens"), params: { password: "staff-only" }
      get public_schedule_path("athens", schedule_id: next_schedule.id, view: "employees", section: "all")
    end

    assert_response :success
    assert_select ".btn-group[aria-label='Schedule week'] a", text: "This Week"
    assert_select ".btn-group[aria-label='Schedule week'] a", text: "Next Week"
    assert_select ".btn-group[aria-label='Schedule view'] .btn.btn-primary", text: "Employees"
    assert_select ".btn-group[aria-label='Schedule section'] .btn.btn-primary", text: "Both"
    assert_select ".shift-pill", text: /12:00-6:00 PM/
  end

  test "public schedule rejects an incorrect password" do
    enable_public_schedule!

    post unlock_public_schedule_path("athens"), params: { password: "wrong" }

    assert_response :unauthorized
    assert_select ".alert", text: "That password did not work."
  end

  private

  def enable_public_schedule!
    accounts(:main).update!(
      public_schedule_enabled: true,
      public_schedule_slug: "athens",
      public_schedule_password: "staff-only"
    )
  end
end
