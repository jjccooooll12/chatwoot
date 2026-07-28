# Public Twilio Voice webhooks for the independently-built (non-enterprise)
# Voice Channel. Twilio calls these directly over HTTP — no agent session,
# authenticated instead by verifying the X-Twilio-Signature header.
class Webhooks::TwilioVoiceController < ApplicationController
  before_action :verify_twilio_signature!
  before_action :set_channel_and_inbox!

  # Phone number's "A call comes in" webhook — the customer leg.
  def call_twiml
    voice_call = create_ringing_call!

    twiml = online_agent_ids.present? ? dial_conference_twiml(voice_call) : voicemail_twiml
    render xml: twiml.to_s
  end

  # TwiML Application's Voice Request URL — hit when an agent's browser
  # Device.connect()s with { To, is_agent, conversation_id, call_sid }.
  def agent_twiml
    voice_call = VoiceCall.find_by(provider_call_id: params[:call_sid], account_id: @account.id)
    return render(xml: Twilio::TwiML::VoiceResponse.new.reject.to_s) unless voice_call

    response = Twilio::TwiML::VoiceResponse.new
    response.dial do |dial|
      dial.conference(
        voice_call.conference_sid,
        start_conference_on_enter: true,
        end_conference_on_exit: true
      )
    end
    render xml: response.to_s
  end

  # Phone number's "Call status changes" webhook — the customer leg's own
  # CallStatus. Only acts while the call is still 'ringing': the conference
  # join/leave events (below) are the source of truth once a conference
  # actually starts, and the recording webhook finalizes the voicemail path.
  def status
    voice_call = VoiceCall.find_by(provider_call_id: params[:CallSid], account_id: @account.id)
    return head :no_content unless voice_call && voice_call.ringing?

    case params[:CallStatus]
    when 'no-answer', 'canceled'
      voice_call.transition_to!(status: 'no_answer', ended_at: Time.current, end_reason: params[:CallStatus])
    when 'busy', 'failed'
      voice_call.transition_to!(status: 'failed', ended_at: Time.current, end_reason: params[:CallStatus])
    when 'completed'
      # The call ended without ever reaching a conference (e.g. hung up
      # while ringing, before the voicemail Record verb or any agent joined).
      voice_call.transition_to!(status: 'no_answer', ended_at: Time.current, end_reason: 'no_answer')
    end

    head :no_content
  end

  # <Conference> statusCallback — set on the Dial/Conference verb itself,
  # not a console setting. 'conference-start' fires when the first
  # start-privileged participant (the agent leg, start_conference_on_enter:
  # true) joins — the customer leg alone never starts it, so this is the
  # reliable "an agent actually answered" signal, not participant-join.
  def conference_status
    voice_call = VoiceCall.find_by(conference_sid: params[:FriendlyName], account_id: @account.id)
    return head :no_content unless voice_call

    case params[:StatusCallbackEvent]
    when 'conference-start'
      voice_call.transition_to!(status: 'in_progress', started_at: Time.current) if voice_call.ringing?
    when 'conference-end'
      finalize_completed_call(voice_call) if voice_call.in_progress?
    end

    head :no_content
  end

  # Fires for both the voicemail <Record> verb and the answered-call
  # <Conference record="record-from-start"> recording. The voicemail case
  # carries CallSid; the conference-recording case may only carry
  # ConferenceSid/FriendlyName — try both. Not yet exercised against live
  # Twilio traffic; confirm the actual param set during throwaway-number
  # testing (see plan verification step) and adjust if needed.
  def recording_status
    return head :no_content unless params[:RecordingStatus] == 'completed'

    voice_call = VoiceCall.find_by(provider_call_id: params[:CallSid], account_id: @account.id) ||
                 VoiceCall.find_by(conference_sid: params[:FriendlyName], account_id: @account.id)
    return head :no_content unless voice_call

    VoiceRecordingDownloadJob.perform_later(voice_call.id, params[:RecordingUrl])
    head :no_content
  end

  private

  def create_ringing_call!
    from_number = params[:From]
    to_number = params[:To]

    contact_inbox = ContactInboxWithContactBuilder.new(
      inbox: @inbox,
      contact_attributes: { name: from_number, phone_number: from_number },
      source_id: "voice:#{from_number}"
    ).perform

    conversation = ConversationBuilder.new(
      params: ActionController::Parameters.new(status: 'open'),
      contact_inbox: contact_inbox
    ).perform

    message = conversation.messages.create!(
      account: @account,
      inbox: @inbox,
      sender: contact_inbox.contact,
      message_type: :incoming,
      content_type: :voice_call,
      content: 'Incoming call'
    )

    VoiceCall.create!(
      account: @account,
      inbox: @inbox,
      conversation: conversation,
      contact: contact_inbox.contact,
      message: message,
      provider_call_id: params[:CallSid],
      direction: 'incoming',
      status: 'ringing',
      conference_sid: "voice-#{SecureRandom.hex(8)}",
      from_number: from_number,
      to_number: to_number
    )
  end

  def dial_conference_twiml(voice_call)
    response = Twilio::TwiML::VoiceResponse.new
    response.dial do |dial|
      dial.conference(
        voice_call.conference_sid,
        start_conference_on_enter: false,
        record: 'record-from-start',
        recording_status_callback: voice_webhook_recording_status_url(phone_number: params[:phone_number]),
        recording_status_callback_event: 'completed',
        status_callback: voice_webhook_conference_status_url(phone_number: params[:phone_number]),
        status_callback_event: 'start end'
      )
    end
    response
  end

  def voicemail_twiml
    response = Twilio::TwiML::VoiceResponse.new
    response.say(message: 'Sorry, nobody is available to take your call right now. Please leave a message after the beep.')
    response.record(
      max_length: 120,
      play_beep: true,
      recording_status_callback: voice_webhook_recording_status_url(phone_number: params[:phone_number]),
      recording_status_callback_event: 'completed'
    )
    response
  end

  def finalize_completed_call(voice_call)
    duration = voice_call.started_at ? (Time.current - voice_call.started_at).round : nil
    voice_call.transition_to!(status: 'completed', ended_at: Time.current, duration_seconds: duration, end_reason: 'completed')
  end

  def online_agent_ids
    member_ids = @inbox.members.pluck(:id)
    online_ids = OnlineStatusTracker.get_available_users(@account.id)
                                     .select { |_id, status| status == 'online' }
                                     .keys.map(&:to_i)
    member_ids & online_ids
  end

  def set_channel_and_inbox!
    phone = "+#{params[:phone_number]}"
    @channel = Channel::Api.find_by("additional_attributes->>'phone_number' = ?", phone)
    return head :not_found unless @channel

    @inbox = @channel.inbox
    @account = @inbox.account
  end

  def verify_twilio_signature!
    validator = Twilio::Security::RequestValidator.new(ENV.fetch('TWILIO_VOICE_AUTH_TOKEN'))
    signature = request.headers['X-Twilio-Signature']
    return if signature.present? && validator.validate(request.original_url, request.request_parameters, signature)

    head :forbidden
  end
end
