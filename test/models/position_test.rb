require "test_helper"

class PositionTest < ActiveSupport::TestCase
  test "position palette includes 36 colors" do
    assert_equal 36, Position::COLOR_PALETTE.size
    assert_equal Position::COLOR_PALETTE.uniq.size, Position::COLOR_PALETTE.size
  end

  test "color must come from the position palette" do
    position = positions(:server)

    position.color = Position::COLOR_PALETTE.last
    assert position.valid?

    position.color = "#123456"
    assert_not position.valid?
    assert_includes position.errors[:color], "is not included in the list"
  end

  test "display color falls back to the first palette color" do
    position = positions(:server)
    position.color = nil

    assert_equal Position::COLOR_PALETTE.first, position.display_color
  end

  test "section must be back of house or front of house" do
    position = positions(:server)

    position.section = "boh"
    assert position.valid?

    position.section = "kitchen"
    assert_not position.valid?
    assert_includes position.errors[:section], "is not included in the list"
  end

  test "new positions are placed at the end of their division order" do
    position = locations(:main).positions.create!(
      name: "Host",
      section: "foh",
      color: Position::COLOR_PALETTE.first
    )

    assert_equal 3, position.position_order
  end
end
