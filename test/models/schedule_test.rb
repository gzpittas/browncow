require "test_helper"

class ScheduleTest < ActiveSupport::TestCase
  test "sunday is accepted as the schedule week start" do
    schedule = locations(:main).schedules.build(week_start_date: Date.new(2026, 6, 28))

    assert schedule.valid?
  end

  test "monday is rejected as the schedule week start" do
    schedule = locations(:main).schedules.build(week_start_date: Date.new(2026, 6, 29))

    assert_not schedule.valid?
    assert_includes schedule.errors[:week_start_date], "must be a Sunday"
  end

  test "week starts on sunday and ends on saturday" do
    schedule = schedules(:main_week)

    assert_equal Date.new(2026, 6, 21), schedule.week_start_date
    assert_equal Date.new(2026, 6, 27), schedule.week_end_date
    assert_equal Date.new(2026, 6, 21), schedule.date_for_day("Sunday")
    assert_equal Date.new(2026, 6, 27), schedule.date_for_day("Saturday")
    assert_equal %w[Sun Mon Tue Wed Thu Fri Sat], schedule.week_dates.map { |date| date.strftime("%a") }
  end

  test "week_start_for returns the current sunday" do
    assert_equal Date.new(2026, 6, 28), Schedule.week_start_for(Date.new(2026, 7, 1))
    assert_equal Date.new(2026, 6, 28), Schedule.week_start_for(Date.new(2026, 6, 28))
  end
end
