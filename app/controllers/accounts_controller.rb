class AccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_existing_account, only: [ :new, :create ]
  before_action :require_account!, only: [ :edit, :update ]

  def new
    @account = Account.new(email: current_user.email)
  end

  def create
    @account = Account.new(account_params)

    Account.transaction do
      @account.save!
      current_user.update!(account: @account)
    end

    redirect_to dashboard_path, notice: "Restaurant account set up."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def edit
    @account = current_user.account
  end

  def update
    @account = current_user.account

    if @account.update(account_params)
      redirect_to dashboard_path, notice: "Account updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def account_params
    params.require(:account).permit(:name, :phone_number, :email)
  end

  def redirect_existing_account
    redirect_to dashboard_path if current_user.account.present?
  end
end
