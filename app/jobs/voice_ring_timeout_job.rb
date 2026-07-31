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

    # This only redirects the live Twilio call - it doesn't touch our own
    # VoiceCall row, so nothing broadcasts and the ringing popup/UI sits
    # frozen on "ringing" for every agent until some later webhook happens to
    # arrive (which can be many seconds off, or race with an agent clicking
    # Answer on a call that already moved on). Settle it here, immediately,
    # so the popup disappears the moment the ring actually times out.
    voice_call.transition_to!(status: 'no_answer', ended_at: Time.current, end_reason: 'no_answer')
    VoiceCallOutcomeCheckJob.set(wait: VoiceCallOutcomeCheckJob::WAIT).perform_later(voice_call.id)
  rescue Twilio::REST::RestError => e
    # Call likely already ended (caller hung up) between the ringing? check
    # and the API call — nothing to do.
    Rails.logger.info("[VoiceRingTimeoutJob] could not redirect call #{voice_call.provider_call_id}: #{e.message}")
  end
end
