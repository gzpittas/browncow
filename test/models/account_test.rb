require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "public schedule password can be set and authenticated" do
    account = Account.new(name: "Athens")

    account.public_schedule_password = "staff-only"

    assert account.public_schedule_password_digest.present?
    assert account.public_schedule_password_authenticated?("staff-only")
    assert_not account.public_schedule_password_authenticated?("wrong")
  end

  test "public schedule slug is required when public schedule is enabled" do
    account = Account.new(name: "Athens", public_schedule_enabled: true, public_schedule_slug: "")

    assert_not account.valid?
    assert_includes account.errors[:public_schedule_slug], "can't be blank"
  end
end
