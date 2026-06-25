module ApplicationHelper
  def schedule_week_label(schedule)
    start_date = schedule.week_start_date
    end_date = schedule.week_end_date

    if start_date.month == end_date.month
      "Week of Sunday #{start_date.strftime("%B %-d")} - #{end_date.strftime("%-d")}"
    else
      "Week of Sunday #{start_date.strftime("%B %-d")} - #{end_date.strftime("%B %-d")}"
    end
  end

  def schedule_print_week_label(schedule)
    start_date = schedule.week_start_date
    end_date = schedule.week_end_date

    if start_date.month == end_date.month
      "Week of #{start_date.strftime("%B %-d")}-#{end_date.strftime("%-d")}, #{end_date.year}"
    else
      "Week of #{start_date.strftime("%B %-d")}-#{end_date.strftime("%B %-d")}, #{end_date.year}"
    end
  end

  def schedule_day_label(date)
    date.strftime("%a %-d")
  end

  def shift_time_range(shift)
    if shift.starts_at.strftime("%p") == shift.ends_at.strftime("%p")
      "#{shift.starts_at.strftime("%-l:%M")}-#{shift.ends_at.strftime("%-l:%M %p")}"
    else
      "#{shift.starts_at.strftime("%-l:%M %p")}-#{shift.ends_at.strftime("%-l:%M %p")}"
    end
  end

  def half_hour_time_options
    (14...48).map do |offset|
      minutes = offset * 30
      time = Time.zone.parse("2000-01-01") + minutes.minutes

      [ time.strftime("%-l:%M %p"), time.strftime("%H:%M") ]
    end
  end

  def time_select_value(value)
    return if value.blank?

    value.respond_to?(:strftime) ? value.strftime("%H:%M") : Time.zone.parse(value.to_s).strftime("%H:%M")
  end

  def schedule_week_options(location, _selected_date = nil)
    first_week = Schedule.week_start_for(Date.current) - 4.weeks
    existing_week_starts = location.schedules.pluck(:week_start_date)

    (0..16).filter_map do |week_offset|
      week_start = first_week + week_offset.weeks
      next if existing_week_starts.include?(week_start)

      [ "Week of #{week_start.strftime("%A, %B %-d")}", week_start.iso8601 ]
    end
  end

  def schedule_copy_source_options(location)
    schedules = location.schedules.ordered.to_a
    current_schedule = Schedule.current_for(location)

    schedules.map do |schedule|
      label = if current_schedule == schedule
        "Current schedule (#{schedule_week_label(schedule)})"
      else
        schedule_week_label(schedule)
      end

      [ label, schedule.id ]
    end
  end
end
