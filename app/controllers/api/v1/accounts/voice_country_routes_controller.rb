# Super-admin-only management of which agents receive inbound Voice calls from
# which country (matched by E.164 phone prefix, e.g. +39 for Italy). A
# country with no configured route rings every online agent on the inbox —
# see Webhooks::TwilioVoiceController#online_agent_ids.
class Api::V1::Accounts::VoiceCountryRoutesController < Api::V1::Accounts::BaseController
  before_action :ensure_super_admin!
  before_action :fetch_inbox
  before_action :fetch_route, only: [:destroy]

  def index
    render json: @inbox.voice_country_routes.includes(:user).order(:country_name, :id).map(&:push_event_data)
  end

  def create
    route = @inbox.voice_country_routes.new(route_params.merge(account_id: Current.account.id))

    if route.save
      render json: route.push_event_data, status: :created
    else
      render json: { errors: route.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @route.destroy!
    head :ok
  end

  private

  # Call routing decides who gets woken up by the phone, so it is deliberately
  # narrower than the rest of settings: account administrators cannot reach it,
  # only the instance super admin.
  def ensure_super_admin!
    render json: { error: 'Super administrators only' }, status: :forbidden unless Current.user.is_a?(SuperAdmin)
  end

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
  end

  def fetch_route
    @route = @inbox.voice_country_routes.find(params[:id])
  end

  def route_params
    params.require(:voice_country_route).permit(:country_name, :phone_prefix, :user_id)
  end
end
