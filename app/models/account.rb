require "bcrypt"

class Account < ApplicationRecord
  has_many :users, dependent: :nullify
  has_many :locations, dependent: :destroy

  validates :name, presence: true
  validates :public_schedule_slug, uniqueness: true, allow_blank: true
  validates :public_schedule_slug, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }, allow_blank: true

  def public_schedule_password=(password)
    self.public_schedule_password_digest = BCrypt::Password.create(password) if password.present?
  end

  def public_schedule_password_authenticated?(password)
    return false if public_schedule_password_digest.blank? || password.blank?

    BCrypt::Password.new(public_schedule_password_digest).is_password?(password)
  end
end
