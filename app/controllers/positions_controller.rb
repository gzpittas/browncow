class PositionsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_account!
  before_action :set_locations
  before_action :set_location
  before_action :set_position, only: [ :edit, :update, :deactivate ]

  def index
    @positions = @location ? @location.positions.order(active: :desc, name: :asc) : Position.none
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
    params.require(:position).permit(:name, :color, :active)
  end
end
