# == Schema Information
#
# Table name: voice_calls
#
#  id                    :bigint           not null, primary key
#  conference_sid        :string
#  direction              :string           default("incoming"), not null
#  duration_seconds       :integer
#  end_reason             :string
#  ended_at                :datetime
#  from_number             :string
#  provider_call_id        :string           not null
#  started_at               :datetime
#  status                   :string           default("ringing"), not null
#  to_number                :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  accepted_by_agent_id     :bigint
#  account_id               :bigint           not null
#  contact_id               :bigint           not null
#  conversation_id          :bigint
#  inbox_id                 :bigint           not null
#  message_id               :bigint
#
# Indexes
#
#  index_voice_calls_on_account_id_and_conversation_id  (account_id,conversation_id)
#  index_voice_calls_on_message_id                      (message_id)
#  index_voice_calls_on_provider_call_id                (provider_call_id) UNIQUE
#

class VoiceCall < ApplicationRecord
  include Rails.application.routes.url_helpers
  include Events::Types

  TERMINAL_STATUSES = %w[completed no_answer no-answer failed rejected].freeze

  enum status: {
    ringing: 'ringing',
    in_progress: 'in-progress',
    completed: 'completed',
    no_answer: 'no-answer',
    failed: 'failed',
    rejected: 'rejected'
  }

  belongs_to :account
  belongs_to :inbox
  belongs_to :conversation, optional: true
  belongs_to :contact
  belongs_to :message, optional: true, inverse_of: :call
  belongs_to :accepted_by_agent, class_name: 'User', optional: true

  has_one_attached :recording

  validates :provider_call_id, presence: true, uniqueness: true

  def push_event_data
    {
      id: id,
      provider_call_id: provider_call_id,
      provider: 'twilio',
      direction: direction,
      status: display_status,
      duration_seconds: duration_seconds,
      end_reason: end_reason,
      conference_sid: conference_sid,
      accepted_by_agent_id: accepted_by_agent_id,
      accepted_by_agent_name: accepted_by_agent&.name,
      started_at: started_at&.to_i,
      ended_at: ended_at&.to_i,
      from_number: from_number,
      to_number: to_number,
      recording_url: recording_url,
      transcript: nil,
      eligible_agent_ids: eligible_agent_ids
    }
  end

  def transition_to!(status:, **attrs)
    previous_status = self.status
    update!(attrs.merge(status: status))
    message&.send_update_event
    broadcast_ended! if terminal_status?(self.status) && previous_status != self.status
  end

  # Empty list means no country route matched this call — every online
  # inbox member is eligible (fail open), matching how the ring-vs-voicemail
  # decision itself treats an unconfigured country.
  def eligible_for?(user_id)
    eligible_agent_ids.blank? || eligible_agent_ids.include?(user_id)
  end

  def outcome_kind
    recording.attached? ? :voicemail : :abandoned
  end

  def outcome_label
    return outgoing_label if outgoing?

    outcome_kind == :voicemail ? 'Voicemail' : 'Abandoned call'
  end

  def outgoing_label
    "Outgoing call to #{callee_display_name}"
  end

  def answered_label
    outgoing? ? outgoing_label : "Incoming call with #{caller_display_name}"
  end

  def outgoing?
    %w[outgoing outbound].include?(direction)
  end

  # Contact#name defaults to the raw phone number at creation (see
  # create_ringing_call!) and only ever changes if an agent later renames the
  # contact — so "still equal to the number" is exactly "no real name known".
  def caller_display_name
    contact.name == from_number ? from_number : contact.name
  end

  def callee_display_name
    return to_number if contact.name.blank?

    contact.name == to_number ? to_number : contact.name
  end

  def display_status
    status.to_s.tr('_', '-')
  end

  private

  def recording_url
    recording.attached? ? url_for(recording) : nil
  end

  def terminal_status?(value)
    TERMINAL_STATUSES.include?(value)
  end

  def broadcast_ended!
    Rails.configuration.dispatcher.dispatch(VOICE_CALL_ENDED, Time.zone.now, voice_call: self)
  end
end
