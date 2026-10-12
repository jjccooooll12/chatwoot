# Rings agents' own phones (a real cell number, not the browser) for an
# incoming call, in parallel with the dashboard's ringing popup.
#
# Configured per Voice inbox on the channel, next to the other Twilio
# identifiers: additional_attributes['forward_numbers'] = { '<user_id>' => '+1...' }.
# Only inbox members the call is routed to (country rules) are rung.
#
# Each forwarded leg is a separate outbound Twilio call from the inbox's own
# number. When it is picked up the person has to press 1 (see
# Webhooks::TwilioVoiceController#forward_twiml) before joining the customer's
# conference, so the cell's own voicemail can never "answer" the customer.
# Joining the conference is what marks the call answered, so the recording,
# ticket relabel and assignment work exactly as for a browser answer.
#
# Leg call SIDs live in a short-lived Redis list so every other leg can be
# hung up the moment anyone answers, the ring times out or the caller leaves.
class Voice::ForwardLegs
  RING_SECONDS = 30
  LEGS_TTL = 10.minutes

  def initialize(voice_call)
    @voice_call = voice_call
    @inbox = voice_call.inbox
    @channel = @inbox.channel
  end

  # { user_id => phone } for the agents this call should ring by phone.
  def targets
    numbers = (@channel.additional_attributes || {})['forward_numbers'] || {}
    member_ids = @inbox.members.pluck(:id)

    numbers.each_with_object({}) do |(user_id, phone), result|
      id = user_id.to_i
      next if phone.blank? || member_ids.exclude?(id) || !@voice_call.eligible_for?(id)

      result[id] = phone
    end
  end

  def ring!
    targets.each do |user_id, phone|
      call = twilio_client.calls.create(
        to: phone,
        from: @voice_call.to_number,
        url: url_helpers.voice_webhook_forward_url(phone_number: phone_digits, conference_sid: @voice_call.conference_sid,
                                                   user_id: user_id),
        method: 'POST',
        timeout: RING_SECONDS
      )
      Redis::Alfred.lpush(legs_key, [call.sid])
      Redis::Alfred.expire(legs_key, LEGS_TTL)
    rescue Twilio::REST::RestError => e
      Rails.logger.warn("[Voice::ForwardLegs] could not ring user #{user_id} for call #{@voice_call.id}: #{e.code} #{e.message}")
    end
  end

  # The leg that accepted stays connected - it is about to join the conference.
  def release!(call_sid)
    Redis::Alfred.lrem(legs_key, call_sid)
  end

  def hang_up_all!
    Redis::Alfred.lrange(legs_key).each { |call_sid| hang_up(call_sid) }
    Redis::Alfred.delete(legs_key)
  end

  private

  # A leg still ringing can only be 'canceled'; one sitting at the press-1
  # prompt is in progress and can only be 'completed'.
  def hang_up(call_sid)
    twilio_client.calls(call_sid).update(status: 'canceled')
  rescue Twilio::REST::RestError
    begin
      twilio_client.calls(call_sid).update(status: 'completed')
    rescue Twilio::REST::RestError => e
      Rails.logger.info("[Voice::ForwardLegs] leg #{call_sid} already ended: #{e.message}")
    end
  end

  def legs_key
    "voice_forward_legs:#{@voice_call.id}"
  end

  def phone_digits
    @voice_call.to_number.delete_prefix('+')
  end

  def twilio_client
    @twilio_client ||= ::Twilio::REST::Client.new(@channel.additional_attributes['twilio_account_sid'],
                                                  ENV.fetch('TWILIO_VOICE_AUTH_TOKEN'))
  end

  def url_helpers
    Rails.application.routes.url_helpers
  end
end
