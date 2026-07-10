class Employee < ApplicationRecord
  belongs_to :location

  has_many :employee_positions, dependent: :destroy
  has_many :positions, through: :employee_positions
  has_many :shifts, dependent: :destroy
  has_many :employee_availability_blocks, dependent: :destroy

  validates :first_name, :last_name, presence: true

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(active: :desc, first_name: :asc, last_name: :asc) }

  def display_name
    [ first_name, last_name ].compact_blank.join(" ")
  end

  def compact_display_name
    [ first_name, last_name.presence&.first ].compact_blank.join(" ")
  end
end
