class Conversations::DeleteService
  pattr_initialize [:conversation!, :user, :ip]

  def perform
    track_deleted_email_messages
    move_emails_to_deleted_items
    ::DeleteObjectJob.perform_later(conversation, user, ip)
  end

  private

  def track_deleted_email_messages
    return unless conversation.inbox.email?

    Imap::DeletedMessageTracker.new(inbox: conversation.inbox).record(conversation.messages.incoming.pluck(:source_id))
  end

  # Soft-delete the ticket's inbound emails in Outlook (move them to Deleted
  # Items). Best-effort: a mailbox hiccup must not block deleting the ticket.
  def move_emails_to_deleted_items
    channel = conversation.inbox.channel
    return unless conversation.inbox.email? && channel.try(:provider) == 'microsoft'

    source_ids = conversation.messages.incoming.pluck(:source_id).compact_blank
    return if source_ids.empty?

    Imap::MicrosoftDeleteEmailService.new(channel: channel).move_to_deleted(source_ids)
  rescue StandardError => e
    Rails.logger.error("[CONVERSATION_DELETE] Move to Deleted Items failed for conversation #{conversation.id}: #{e.message}")
    ChatwootExceptionTracker.new(e).capture_exception if defined?(ChatwootExceptionTracker)
  end
end
