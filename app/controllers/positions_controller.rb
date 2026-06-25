class PositionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_account!
  before_action :set_locations
  before_action :set_location
  before_action :set_position, only: [ :edit, :update, :deactivate ]

  def index
    @boh_positions = @location ? @location.positions.boh.ordered : Position.none
    @foh_positions = @location ? @location.positions.foh.ordered : Position.none
  end

  def new
    @position = @location.positions.build
  end

  def create
    @position = @location.positions.build(position_params)

    if @position.save
      redirect_to location_positions_path(@location), notice: "Position added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @position.update(position_params)
      redirect_to location_positions_path(@location), notice: "Position updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def deactivate
    @position.update!(active: false)
    redirect_to location_positions_path(@location), notice: "Position marked inactive."
  end

  def reorder
    section = params.require(:position).fetch(:section)
    ordered_ids = Array(params[:position][:ordered_ids]).map(&:to_i)
    positions = @location.positions.where(id: ordered_ids)

    if !Position::SECTIONS.key?(section) || positions.size != ordered_ids.size || positions.where.not(section: section).exists?
      head :unprocessable_entity
      return
    end

    Position.transaction do
      ordered_ids.each_with_index do |id, index|
        positions.find { |position| position.id == id }&.update_columns(position_order: index + 1)
      end
    end

    head :ok
  end

  private

  def set_locations
    @locations = current_user.account.locations.order(active: :desc, name: :asc)
  end

  def set_location
    @location = if params[:location_id].present?
      current_user.account.locations.find(params[:location_id])
    else
      @locations.first
    end
  end

  def set_position
    @position = @location.positions.find(params[:id])
  end

  def position_params
    params.require(:position).permit(:name, :section, :color, :active)
  end
end
