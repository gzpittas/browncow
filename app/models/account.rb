class Account < ApplicationRecord
  has_many :users, dependent: :nullify
  has_many :locations, dependent: :destroy

  validates :name, presence: true
end
