class WelcomeController < ApplicationController
  def index
    redirect_to signed_in_landing_path_for(current_user) if user_signed_in?
  end
end
