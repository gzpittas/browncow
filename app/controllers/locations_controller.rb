class LocationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_account!
  before_action :set_location, only: [ :edit, :update, :deactivate ]

  def index
    @locations = current_user.account.locations.order(active: :desc, name: :asc)
  end

  def new
    @location = current_user.account.locations.build
  end

  def create
    @location = current_user.account.locations.build(location_params)

    if @location.save
      redirect_to locations_path, notice: "Location added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @location.update(location_params)
      redirect_to locations_path, notice: "Location updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def deactivate
    @location.update!(active: false)
    redirect_to locations_path, notice: "Location marked inactive."
  end

  private

  def set_location
    @location = current_user.account.locations.find(params[:id])
  end

  def location_params
    params.require(:location).permit(:name, :address_line_1, :city, :state, :postal_code, :active)
  end
end
