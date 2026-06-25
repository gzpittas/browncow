class Employee < ApplicationRecord
  belongs_to :location

  has_many :employee_positions, dependent: :destroy
  has_many :positions, through: :employee_positions
  has_many :shifts, dependent: :destroy

  validates :first_name, :last_name, presence: true

  scope :active, -> { where(active: true) }

  def display_name
    [ first_name, last_name ].compact_blank.join(" ")
  end
end
