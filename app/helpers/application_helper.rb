module ApplicationHelper
  def schedule_header_title(schedule)
    "Week of Sunday #{schedule.week_start_date.strftime("%B %-d")}"
  end

  def schedule_week_label(schedule)
    schedule_header_title(schedule)
  end

  def schedule_print_week_label(schedule)
    "#{schedule_week_label(schedule)}, #{schedule.week_end_date.year}"
  end

  def schedule_day_label(date)
    date.strftime("%a %-d")
  end

  def schedule_print_position_day_label(date)
    "#{date.strftime("%a").upcase} #{date.strftime("%-d")}"
  end

  def schedule_header_day_name(date)
    date.strftime("%a").upcase
  end

  def schedule_today?(date)
    date == Date.current
  end

  def schedule_weekend?(date)
    date.sunday? || date.saturday?
  end

  def schedule_mini_month_weeks(date)
    month_start = date.beginning_of_month
    month_end = date.end_of_month
    grid_start = month_start.beginning_of_week(:sunday)
    grid_end = month_end.end_of_week(:sunday)

    (grid_start..grid_end).to_a.each_slice(7)
  end

  def schedule_mini_month_title(date)
    date.strftime("%B %Y")
  end

  def schedule_mini_month_destination(location, date, view:, section:)
    week_start = Schedule.week_start_for(date)
    target_schedule = schedule_mini_month_schedule_lookup(location, date: date)[week_start]

    if target_schedule.present?
      location_schedule_path(location, target_schedule, view: view, section: section)
    else
      new_location_schedule_path(location, week_start_date: week_start.iso8601, view: view, section: section)
    end
  end

  def schedule_mini_month_has_schedule?(location, date)
    schedule_mini_month_schedule_lookup(location, date: date).key?(Schedule.week_start_for(date))
  end

  def schedule_mini_month_schedule_lookup(location, date:)
    @schedule_mini_month_schedule_lookup ||= {}
    cache_key = [ location.id, date.beginning_of_month ]

    @schedule_mini_month_schedule_lookup[cache_key] ||= begin
      month_start = date.beginning_of_month.beginning_of_week(:sunday)
      month_end = date.end_of_month.end_of_week(:sunday)

      location.schedules
        .where(week_start_date: month_start..month_end)
        .index_by(&:week_start_date)
    end
  end

  def shift_time_range(shift)
    if shift.starts_at.strftime("%p") == shift.ends_at.strftime("%p")
      "#{shift.starts_at.strftime("%-l:%M")}-#{shift.ends_at.strftime("%-l:%M %p")}"
    else
      "#{shift.starts_at.strftime("%-l:%M %p")}-#{shift.ends_at.strftime("%-l:%M %p")}"
    end
  end

  def shift_time_range_lines(shift)
    [
      shift.starts_at.strftime("%-l:%M %p"),
      shift.ends_at.strftime("%-l:%M %p")
    ]
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

  def schedule_week_options(location, selected_date = nil)
    first_week = Schedule.week_start_for(Date.current) - 4.weeks
    existing_week_starts = location.schedules.pluck(:week_start_date)
    selected_week = selected_date&.to_date

    week_starts = (0..16).map { |week_offset| first_week + week_offset.weeks }
    week_starts << selected_week if selected_week.present?

    week_starts.uniq.sort.filter_map do |week_start|
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

  def schedule_copy_section_options
    [
      [ "BOH only", "boh" ],
      [ "FOH only", "foh" ],
      [ "BOH + FOH", "all" ]
    ]
  end

  def position_section_options
    Position::SECTIONS.map { |key, label| [ label, key ] }
  end
end
