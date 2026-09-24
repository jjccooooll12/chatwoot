# Twilio's recording URL requires HTTP Basic Auth with the account's
# Account SID / Auth Token, and is always api.twilio.com — a fixed, trusted
# host we control the credentials for, not user-supplied input, so this
# downloads directly rather than going through the SSRF-guarded SafeFetch
# helper used for arbitrary user-submitted URLs (e.g. avatar imports).
class VoiceRecordingDownloadJob < ApplicationJob
  # Twilio can answer a just-completed recording with a 404 for a short while,
  # and the network can fail. Either used to drop the recording silently, so
  # raise and let ActiveJob retry instead.
  class RecordingUnavailable < StandardError; end

  queue_as :low
  retry_on RecordingUnavailable, Net::OpenTimeout, Net::ReadTimeout, wait: 30.seconds, attempts: 10

  # The .wav is Twilio's lossless original; the .mp3 variant is a 32 kbps
  # transcode, so we keep the original.
  def perform(voice_call_id, recording_url)
    voice_call = VoiceCall.find_by(id: voice_call_id)
    return if voice_call.nil? || voice_call.recording.attached?

    uri = URI("#{recording_url}.wav")
    response = fetch(uri, account_sid: twilio_account_sid(voice_call))
    raise RecordingUnavailable, "#{uri} returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    voice_call.recording.attach(
      io: StringIO.new(response.body),
      filename: "voice_call_#{voice_call.id}.wav",
      content_type: 'audio/wav'
    )

    voice_call.transition_to!(status: 'no_answer', ended_at: Time.current, end_reason: 'no_answer') if voice_call.ringing?

    # This job also fires for an *answered* call's conference recording
    # (record: 'record-from-start' on the Dial/Conference verb shares the
    # same recording_status_callback) — only unanswered outcomes get
    # relabeled/merged as a voicemail.
    unanswered_statuses = %w[no_answer failed rejected]
    Voice::CallOutcomeFinalizer.new(voice_call: voice_call).perform if unanswered_statuses.include?(voice_call.status)
  end

  private

  def twilio_account_sid(voice_call)
    voice_call.inbox.channel.additional_attributes['twilio_account_sid']
  end

  def fetch(uri, account_sid:)
    request = Net::HTTP::Get.new(uri)
    request.basic_auth(account_sid, ENV.fetch('TWILIO_VOICE_AUTH_TOKEN'))

    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
      http.request(request)
    end
  end
end
