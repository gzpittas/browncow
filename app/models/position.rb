class Position < ApplicationRecord
  SECTIONS = {
    "boh" => "Back of House",
    "foh" => "Front of House"
  }.freeze

  COLOR_PALETTE = [
    "#8C3C2E",
    "#8A4F2A",
    "#A67C00",
    "#2F6B45",
    "#2F5F8F",
    "#5E3B84",
    "#6F5D4D",
    "#4D5968",
    "#D8D3CA",
    "#A94A35",
    "#A85B2C",
    "#C0951A",
    "#3F8F5F",
    "#2E7FA3",
    "#6E4D8F",
    "#8A725E",
    "#627082",
    "#E6E1D8",
    "#B44D5E",
    "#B85C38",
    "#D8A31A",
    "#58A36E",
    "#496FA8",
    "#8C5A97",
    "#A58A73",
    "#8F99A3",
    "#F1ECE3",
    "#CF6878",
    "#C47F2C",
    "#E0B84D",
    "#7BB78B",
    "#6FA3D1",
    "#A16FAF",
    "#C2AE98",
    "#C5CCD3",
    "#FFFFFF"
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
