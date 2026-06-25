class Location < ApplicationRecord
  belongs_to :account

  has_many :positions, dependent: :destroy
  has_many :employees, dependent: :destroy
  has_many :schedules, dependent: :destroy

  validates :name, presence: true

  scope :active, -> { where(active: true) }
end
