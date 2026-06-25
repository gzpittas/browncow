class Position < ApplicationRecord
  SECTIONS = {
    "boh" => "Back of House",
    "foh" => "Front of House"
  }.freeze

  COLOR_PALETTE = [
    "#8A4F2A",
    "#B85C38",
    "#C47F2C",
    "#D8A31A",
    "#7F9B3A",
    "#3F8F5F",
    "#2F8C83",
    "#2E7FA3",
    "#496FA8",
    "#6A5FA8",
    "#8C5A97",
    "#B04F75",
    "#8A5A44",
    "#6F6A55",
    "#4D6A5B",
    "#4D5968"
  ].freeze

  belongs_to :location

  has_many :employee_positions, dependent: :destroy
  has_many :employees, through: :employee_positions
  has_many :shifts, dependent: :destroy

  before_validation :assign_position_order, on: :create
  before_validation :move_to_division_end, if: :will_save_change_to_section?

  validates :name, :section, presence: true
  validates :section, inclusion: { in: SECTIONS.keys }
  validates :color, presence: true, inclusion: { in: COLOR_PALETTE }
  validates :position_order, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }
  scope :boh, -> { where(section: "boh") }
  scope :foh, -> { where(section: "foh") }
  scope :ordered, lambda {
    order(active: :desc)
      .order(Arel.sql("CASE section WHEN 'boh' THEN 0 WHEN 'foh' THEN 1 ELSE 2 END"))
      .order(:position_order, :name)
  }

  def display_color
    color.presence || COLOR_PALETTE.first
  end

  def section_label
    SECTIONS.fetch(section)
  end

  def insert_at!(new_position)
    transaction do
      siblings = location.positions.where(section: section).where.not(id: id).ordered.to_a
      target_index = [[new_position.to_i - 1, 0].max, siblings.length].min
      siblings.insert(target_index, self)

      siblings.each_with_index do |position, index|
        position.update_columns(position_order: index + 1)
      end
    end
  end

  private

  def assign_position_order
    return if position_order.to_i.positive?

    self.position_order = next_position_order_for(section)
  end

  def move_to_division_end
    return if new_record?
    return unless section.present?

    self.position_order = next_position_order_for(section)
  end

  def next_position_order_for(target_section)
    sibling_scope = location.positions.where(section: target_section)
    sibling_scope = sibling_scope.where.not(id: id) if persisted?
    sibling_scope.maximum(:position_order).to_i + 1
  end
end
