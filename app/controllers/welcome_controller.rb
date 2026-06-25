class WelcomeController < ApplicationController
  def index
    return redirect_to signed_in_landing_path_for(current_user) if user_signed_in?

    redirect_to new_user_session_path
  end
end
