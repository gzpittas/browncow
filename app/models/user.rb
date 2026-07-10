class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :account, optional: true

  validates :schedule_section_preference, inclusion: { in: ApplicationController::SCHEDULE_SECTION_MODES }
  validates :schedule_foh_view_preference, :schedule_boh_view_preference, inclusion: { in: ApplicationController::SCHEDULE_VIEW_MODES }
  validates :schedule_foh_employee_order_preference, :schedule_boh_employee_order_preference, inclusion: { in: %w[alphabetical ranked] }

  def display_name
    [ first_name, last_name ].compact_blank.join(" ").presence || email
  end
end
