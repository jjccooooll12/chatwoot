# Gives a genuine voicemail recording a chance to arrive (via the separate,
# async recording_status webhook -> VoiceRecordingDownloadJob) before
# settling an unanswered call's outcome. If a recording shows up first,
# VoiceRecordingDownloadJob's own finalizer call already handles it and this
# is a no-op.
class VoiceCallOutcomeCheckJob < ApplicationJob
  queue_as :default

  WAIT = 15.seconds

  def perform(voice_call_id)
    voice_call = VoiceCall.find_by(id: voice_call_id)
    return if voice_call.nil?

    Voice::CallOutcomeFinalizer.new(voice_call: voice_call).perform
  end
end
