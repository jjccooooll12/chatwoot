# Runs once a call's fate is settled — either a recording never showed up
# within the grace window (VoiceCallOutcomeCheckJob) or one just attached
# (VoiceRecordingDownloadJob). Relabels the ticket to reflect the real
# outcome and folds repeat unanswered attempts from the same number into a
# single open ticket, always preferring a voicemail as the survivor.
class Voice::CallOutcomeFinalizer
  pattr_initialize [:voice_call!]

  def perform
    voice_call.reload
    return if voice_call.message.nil?
    return if voice_call.message.content == voice_call.outcome_label

    relabel!
    merge_with_sibling! if voice_call.conversation.open?
  end

  private

  delegate :outcome_kind, to: :voice_call

  def relabel!
    voice_call.message.update!(content: voice_call.outcome_label)
    voice_call.message.send_update_event
    update_mail_subject!
  end

  # The ticket list title reads additional_attributes['mail_subject'], which
  # Message#ensure_conversation_subject sets once, permanently, at message
  # creation time, and takes priority over message.content in the frontend's
  # subject computed — without this, the list keeps showing the stock
  # "Incoming call" forever even after the content update above.
  def update_mail_subject!
    conversation = voice_call.conversation
    conversation.update_columns( # rubocop:disable Rails/SkipsModelValidations
      additional_attributes: conversation.additional_attributes.merge('mail_subject' => voice_call.outcome_label)
    )
  end

  def merge_with_sibling!
    existing_voicemail, existing_abandoned = siblings.partition { |call| call.outcome_kind == :voicemail }.map(&:first)
    primary_conversation, secondary_conversation = merge_target(existing_voicemail, existing_abandoned)
    return unless primary_conversation

    Conversations::MergeService.new(
      account: voice_call.account,
      primary_conversation: primary_conversation,
      secondary_conversation: secondary_conversation,
      user: nil
    ).perform
  end

  # Voicemails never merge into each other; a voicemail always ends up
  # primary over an abandoned sibling regardless of which arrived more
  # recently; two abandoned calls merge with the newest as primary.
  def merge_target(existing_voicemail, existing_abandoned)
    if outcome_kind == :voicemail
      return [nil, nil] if existing_voicemail
      return [nil, nil] unless existing_abandoned

      [voice_call.conversation, existing_abandoned.conversation]
    elsif existing_voicemail
      [existing_voicemail.conversation, voice_call.conversation]
    elsif existing_abandoned
      [voice_call.conversation, existing_abandoned.conversation]
    else
      [nil, nil]
    end
  end

  def siblings
    VoiceCall.where(inbox_id: voice_call.inbox_id, from_number: voice_call.from_number, status: %w[no_answer failed rejected])
             .where.not(id: voice_call.id)
             .joins(:conversation)
             .where(conversations: { status: Conversation.statuses[:open] })
             .order(created_at: :desc)
  end
end
