require "test_helper"

class ShiftTest < ActiveSupport::TestCase
  test "shift on saturday is valid" do
    shift = schedules(:main_week).shifts.build(
      employee: employees(:sam),
      position: positions(:server),
      shift_date: Date.new(2026, 6, 27),
      starts_at: "16:00",
      ends_at: "22:00"
    )

    assert shift.valid?
  end

  test "shift on following sunday is outside the schedule week" do
    shift = schedules(:main_week).shifts.build(
      employee: employees(:sam),
      position: positions(:server),
      shift_date: Date.new(2026, 6, 28),
      starts_at: "16:00",
      ends_at: "22:00"
    )

    assert_not shift.valid?
    assert_includes shift.errors[:shift_date], "must fall inside the schedule week"
  end
end
