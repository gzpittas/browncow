require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "public schedule password can be set and authenticated" do
    account = Account.new(name: "Athens")

    account.public_schedule_password = "staff-only"

    assert account.public_schedule_password_digest.present?
    assert account.public_schedule_password_authenticated?("staff-only")
    assert_not account.public_schedule_password_authenticated?("wrong")
  end
end
