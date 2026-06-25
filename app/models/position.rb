class Position < ApplicationRecord
  COLOR_PALETTE = [
    "#8A4F2A",
    "#B85C38",
    "#C47F2C",
    "#D8A31A",
    "#7F9B3A",
    "#3F8F5F",
    "#2F8C83",
    "#2E7FA3",
    "#496FA8",
    "#6A5FA8",
    "#8C5A97",
    "#B04F75",
    "#8A5A44",
    "#6F6A55",
    "#4D6A5B",
    "#4D5968"
  ].freeze

  belongs_to :location

  has_many :employee_positions, dependent: :destroy
  has_many :employees, through: :employee_positions
  has_many :shifts, dependent: :destroy

  validates :name, presence: true
  validates :color, presence: true, inclusion: { in: COLOR_PALETTE }

  scope :active, -> { where(active: true) }

  def display_color
    color.presence || COLOR_PALETTE.first
  end
end
