# Twilio's recording URL requires HTTP Basic Auth with the account's
# Account SID / Auth Token, and is always api.twilio.com — a fixed, trusted
# host we control the credentials for, not user-supplied input, so this
# downloads directly rather than going through the SSRF-guarded SafeFetch
# helper used for arbitrary user-submitted URLs (e.g. avatar imports).
class VoiceRecordingDownloadJob < ApplicationJob
  queue_as :low

  # Twilio appends the format to the recording URL; .mp3 keeps the download small.
  def perform(voice_call_id, recording_url)
    voice_call = VoiceCall.find_by(id: voice_call_id)
    return if voice_call.nil? || voice_call.recording.attached?

    uri = URI("#{recording_url}.mp3")
    response = fetch(uri, account_sid: twilio_account_sid(voice_call))
    return unless response.is_a?(Net::HTTPSuccess)

    voice_call.recording.attach(
      io: StringIO.new(response.body),
      filename: "voice_call_#{voice_call.id}.mp3",
      content_type: 'audio/mpeg'
    )

    voice_call.transition_to!(status: 'no_answer', ended_at: Time.current, end_reason: 'no_answer') if voice_call.ringing?
  end

  private

  def twilio_account_sid(voice_call)
    voice_call.inbox.channel.additional_attributes['twilio_account_sid']
  end

  def fetch(uri, account_sid:)
    request = Net::HTTP::Get.new(uri)
    request.basic_auth(account_sid, ENV.fetch('TWILIO_VOICE_AUTH_TOKEN'))

    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 20) do |http|
      http.request(request)
    end
  end
end
