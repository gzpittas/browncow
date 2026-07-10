class EmployeeAvailabilityBlock < ApplicationRecord
  KINDS = {
    "request_off" => "Request Off",
    "unavailable" => "Unavailable"
  }.freeze

  belongs_to :employee

  validates :kind, presence: true, inclusion: { in: KINDS.keys }
  validates :weekday, inclusion: { in: 0..6 }, allow_nil: true
  validates :date, presence: true, if: :request_off?
  validates :weekday, presence: true, if: :unavailable?
  validate :request_off_does_not_use_weekday
  validate :unavailable_does_not_use_date
  validate :ends_at_is_after_starts_at

  scope :active, -> { where(active: true) }
  scope :request_off, -> { where(kind: "request_off") }
  scope :unavailable, -> { where(kind: "unavailable") }

  def request_off?
    kind == "request_off"
  end

  def unavailable?
    kind == "unavailable"
  end

  def label
    KINDS.fetch(kind)
  end

  def short_label
    request_off? ? "R/O" : "UN/A"
  end

  private

  def request_off_does_not_use_weekday
    return unless request_off? && weekday.present?

    errors.add(:weekday, "is only used for recurring unavailable days")
  end

  def unavailable_does_not_use_date
    return unless unavailable? && date.present?

    errors.add(:date, "is only used for request off markers")
  end

  def ends_at_is_after_starts_at
    return if starts_at.blank? || ends_at.blank?
    return if ends_at > starts_at

    errors.add(:ends_at, "must be after the start time")
  end
end
