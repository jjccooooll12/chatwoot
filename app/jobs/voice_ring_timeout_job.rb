# If nobody answers an inbound call within RING_TIMEOUT, the caller
# shouldn't be left waiting silently in the conference indefinitely —
# redirect the live call to the voicemail TwiML instead.
class VoiceRingTimeoutJob < ApplicationJob
  queue_as :default

  RING_TIMEOUT = 25.seconds

  def perform(voice_call_id)
    voice_call = VoiceCall.find_by(id: voice_call_id)
    return unless voice_call&.ringing?

    channel = voice_call.inbox.channel
    client = ::Twilio::REST::Client.new(
      channel.additional_attributes['twilio_account_sid'],
      ENV.fetch('TWILIO_VOICE_AUTH_TOKEN')
    )
    redirect_url = Rails.application.routes.url_helpers.voice_webhook_ring_timeout_url(
      phone_number: voice_call.to_number.delete_prefix('+')
    )
    client.calls(voice_call.provider_call_id).update(url: redirect_url, method: 'POST')
  rescue Twilio::REST::RestError => e
    # Call likely already ended (caller hung up) between the ringing? check
    # and the API call — nothing to do.
    Rails.logger.info("[VoiceRingTimeoutJob] could not redirect call #{voice_call.provider_call_id}: #{e.message}")
  end
end
