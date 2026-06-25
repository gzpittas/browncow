require "test_helper"

class PositionTest < ActiveSupport::TestCase
  test "color must come from the position palette" do
    position = positions(:server)

    position.color = Position::COLOR_PALETTE.last
    assert position.valid?

    position.color = "#FFFFFF"
    assert_not position.valid?
    assert_includes position.errors[:color], "is not included in the list"
  end

  test "display color falls back to the first palette color" do
    position = positions(:server)
    position.color = nil

    assert_equal Position::COLOR_PALETTE.first, position.display_color
  end
end
