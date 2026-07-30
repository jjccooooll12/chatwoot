# Agent-facing endpoints for the independently-built (non-enterprise) Voice
# Channel. Mounted at the same /inboxes/:inbox_id/conference[...] path the
# existing core `voiceAPIClient.js` already calls — that path is a fixed
# data contract in MIT frontend code, not enterprise's protected surface.
class Api::V1::Accounts::VoiceConferenceController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :authorize_inbox_access!
  before_action :fetch_voice_call, only: [:create, :destroy]

  # GET .../conference/token — Twilio Access Token for this agent's browser Device.
  def token
    channel = @inbox.channel

    grant = ::Twilio::JWT::AccessToken::VoiceGrant.new
    grant.outgoing_application_sid = channel.additional_attributes['twilio_twiml_app_sid']
    grant.incoming_allow = true

    access_token = ::Twilio::JWT::AccessToken.new(
      channel.additional_attributes['twilio_account_sid'],
      channel.additional_attributes['twilio_api_key_sid'],
      ENV.fetch('TWILIO_VOICE_API_KEY_SECRET'),
      [grant],
      identity: "agent_#{current_user.id}",
      ttl: 3600
    )

    render json: { token: access_token.to_jwt, account_id: Current.account.id }
  end

  # POST .../conference — agent answers. Atomic first-agent-wins claim.
  def create
    unless @voice_call.eligible_for?(current_user.id)
      return render json: { error: 'This call is routed to a different agent' }, status: :forbidden
    end

    claimed = VoiceCall.where(id: @voice_call.id, accepted_by_agent_id: nil)
                        .update_all(accepted_by_agent_id: current_user.id, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

    if claimed.zero? && @voice_call.reload.accepted_by_agent_id != current_user.id
      return render json: { error: 'Call already answered' }, status: :conflict
    end

    # Auto-assignment is off for the Voice inbox (every online agent needs to
    # see the ringing popup, not just whoever it round-robins to) — assign
    # the conversation here instead, to whoever actually answered.
    @voice_call.conversation.update!(assignee_id: current_user.id) if @voice_call.conversation.assignee_id.blank?

    render json: { conference_sid: @voice_call.conference_sid }
  end

  # DELETE .../conference — agent leaves/declines. If this agent is the
  # connected one, the browser's own Device disconnect (end_conference_on_exit
  # on the agent leg) is what actually ends the call on Twilio's side;
  # conference_status finalizes the VoiceCall. If this agent never joined,
  # other ringing agents may still answer, so nothing is torn down here —
  # see the plan's documented v1 limitation.
  def destroy
    head :ok
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
  end

  def authorize_inbox_access!
    authorize @inbox, :show?
  end

  def fetch_voice_call
    conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
    @voice_call = VoiceCall.find_by!(provider_call_id: params[:call_sid], conversation_id: conversation.id)
  end
end
