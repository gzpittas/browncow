class Schedule < ApplicationRecord
  DAYS_IN_WEEK = 7

  belongs_to :location

  has_many :shifts, dependent: :destroy

  validates :week_start_date, :status, presence: true
  validates :week_start_date, uniqueness: { scope: :location_id }
  validate :week_start_date_is_sunday

  scope :ordered, -> { order(week_start_date: :desc) }

  def self.week_start_for(date)
    date = date.to_date
    date - date.wday
  end

  def week_end_date
    week_start_date + (DAYS_IN_WEEK - 1).days
  end

  def date_for_day(day_of_week)
    week_start_date + day_index(day_of_week).days
  end

  def week_dates
    (week_start_date..week_end_date).to_a
  end

  def draft?
    status == "draft"
  end

  private

  def week_start_date_is_sunday
    return if week_start_date.blank?
    return if week_start_date.sunday?

    errors.add(:week_start_date, "must be a Sunday")
  end

  def day_index(day_of_week)
    case day_of_week
    when Integer
      day_of_week
    when Date
      (day_of_week - week_start_date).to_i
    else
      %w[sunday monday tuesday wednesday thursday friday saturday].index(day_of_week.to_s.downcase) ||
        %w[sun mon tue wed thu fri sat].index(day_of_week.to_s.downcase)
    end
  end
end
