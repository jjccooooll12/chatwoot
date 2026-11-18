# Peach Labels: two friendly bot messages — "a real agent will be with you
# shortly", then the email request as the next chat message — answered in
# plain text, instead of upstream's "Give the team a way to reach you." plus an
# email input box, which visitors found cumbersome. The reply is picked up by
# MessageTemplates::HookExecutionService#capture_email_from_message.
class MessageTemplates::Template::EmailCollect
  REQUESTED_FLAG = 'email_requested'.freeze

  pattr_initialize [:conversation!]

  def perform
    Conversation.transaction do
      # The hook can run again with a stale conversation or overlap another
      # message callback, so lock the row and recheck the flag from the DB.
      # Not `with_lock`: on a brand-new conversation the in-memory record has a
      # dirty display_id (load_attributes_created_by_db_triggers), and lock!
      # raises on unsaved changes — that silently skipped the email ask on
      # every new web chat (ticket 2611183).
      current = Conversation.where(id: conversation.id).lock.pick(:additional_attributes) || {}
      next if current[REQUESTED_FLAG].present?

      conversation.update!(additional_attributes: current.merge(REQUESTED_FLAG => true))
      conversation.messages.create!(template_message_params('agent_on_the_way_message_body'))
      conversation.messages.create!(template_message_params('email_request_message_body'))
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: conversation.account).capture_exception
    true
  end

  private

  def template_message_params(key)
    {
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :template,
      content: I18n.t("conversations.templates.#{key}")
    }
  end
end
