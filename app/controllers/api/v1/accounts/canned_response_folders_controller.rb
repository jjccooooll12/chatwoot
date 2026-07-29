class Api::V1::Accounts::CannedResponseFoldersController < Api::V1::Accounts::BaseController
  before_action :fetch_folder, only: [:update, :destroy]

  def index
    render json: Current.account.canned_response_folders.order(:name)
  end

  def create
    @folder = Current.account.canned_response_folders.create!(permitted_params)
    render json: @folder
  end

  def update
    @folder.update!(permitted_params)
    render json: @folder
  end

  def destroy
    @folder.destroy!
    head :ok
  end

  private

  def fetch_folder
    @folder = Current.account.canned_response_folders.find(params[:id])
  end

  def permitted_params
    params.permit(:name)
  end
end
