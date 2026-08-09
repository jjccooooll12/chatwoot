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

    # The ring can time out (or the caller can hang up) in the moment between
    # the popup rendering and the agent clicking Answer - without this, that
    # race silently "succeeds" into a broken state: accepted_by_agent_id set
    # on a call that's already no_answer. 409 here is the same response the
    # frontend already treats as "someone else got it" (tears down the local
    # Device, dismisses the popup), so this reuses an existing handled path.
    unless @voice_call.ringing?
      return render json: { error: 'This call is no longer available' }, status: :conflict
    end

    claimed = VoiceCall.where(id: @voice_call.id, accepted_by_agent_id: nil)
                        .update_all(accepted_by_agent_id: current_user.id, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

    if claimed.zero? && @voice_call.reload.accepted_by_agent_id != current_user.id
      return render json: { error: 'Call already answered' }, status: :conflict
    end

    # Auto-assignment is off for the Voice inbox (every online agent needs to
    # see the ringing popup, not just whoever it round-robins to) — assign
    # the conversation here instead, to whoever actually answered.
    conversation = @voice_call.conversation
    conversation.update!(assignee_id: current_user.id) if conversation && conversation.assignee_id.blank?

    render json: { conference_sid: @voice_call.conference_sid }
  end

  # DELETE .../conference — agent leaves/declines. Do not rely only on the
  # browser Device disconnect: for outbound PSTN calls that can leave the
  # customer's Twilio leg alive. Complete the provider call explicitly so the
  # red button always hangs up the real phone call too.
  def destroy
    terminate_provider_call!
    finalize_agent_ended_call!

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
    @voice_call = VoiceCall.find_by!(
      account_id: Current.account.id,
      inbox_id: @inbox.id,
      provider_call_id: params[:call_sid]
    )
  end

  def terminate_provider_call!
    return if @voice_call.provider_call_id.start_with?(Api::V1::Accounts::CallsController::PENDING_PROVIDER_CALL_PREFIX)

    twilio_client.calls(@voice_call.provider_call_id).update(status: 'completed')
  rescue Twilio::REST::RestError => e
    Rails.logger.warn(
      "[VoiceConferenceController] Failed to terminate Twilio call #{@voice_call.provider_call_id}: #{e.code} #{e.message}"
    )
  end

  def finalize_agent_ended_call!
    return if VoiceCall::TERMINAL_STATUSES.include?(@voice_call.status)

    duration = @voice_call.started_at ? (Time.current - @voice_call.started_at).round : nil
    @voice_call.transition_to!(
      status: 'completed',
      ended_at: Time.current,
      duration_seconds: duration,
      end_reason: 'agent_hangup'
    )
  end

  def twilio_client
    @twilio_client ||= ::Twilio::REST::Client.new(
      twilio_voice_attributes['twilio_api_key_sid'],
      ENV.fetch('TWILIO_VOICE_API_KEY_SECRET'),
      twilio_voice_attributes['twilio_account_sid']
    )
  end

  def twilio_voice_attributes
    @twilio_voice_attributes ||= @inbox.channel.additional_attributes || {}
  end
end
