class Api::V1::Accounts::CannedResponsesController < Api::V1::Accounts::BaseController
  before_action :fetch_canned_response, only: [:update, :destroy]
  before_action :check_authorization, only: [:update, :destroy]

  def index
    render json: canned_responses
  end

  def create
    @canned_response = Current.account.canned_responses.new(permitted_params.merge(created_by_id: current_user.id))
    @canned_response.set_visibility(current_user, permitted_params)
    @canned_response.save!
    render json: @canned_response
  end

  def update
    @canned_response.assign_attributes(permitted_params.merge(updated_by_id: current_user.id))
    @canned_response.set_visibility(current_user, permitted_params)
    @canned_response.save!
    render json: @canned_response
  end

  def destroy
    @canned_response.destroy!
    head :ok
  end

  private

  def fetch_canned_response
    @canned_response = Current.account.canned_responses.find(params[:id])
  end

  def permitted_params
    params.permit(:short_code, :content, :visibility, :folder_id)
  end

  def canned_responses
    scope = CannedResponse.with_visibility(current_user, params)
    if params[:search]
      scope.where('short_code ILIKE :search OR content ILIKE :search', search: "%#{params[:search]}%")
           .order_by_search(params[:search])
    else
      scope
    end
  end

  def check_authorization
    authorize(@canned_response) if @canned_response.present?
  end
end
