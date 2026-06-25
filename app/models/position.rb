class Position < ApplicationRecord
  belongs_to :location

  has_many :employee_positions, dependent: :destroy
  has_many :employees, through: :employee_positions
  has_many :shifts, dependent: :destroy

  validates :name, presence: true

  scope :active, -> { where(active: true) }
end
