# Peach Labels: two friendly bot messages — "a real agent will be with you
# shortly", then the email request as the next chat message — answered in
# plain text, instead of upstream's "Give the team a way to reach you." plus an
# email input box, which visitors found cumbersome. The reply is picked up by
# MessageTemplates::HookExecutionService#capture_email_from_message.
class MessageTemplates::Template::EmailCollect
  REQUESTED_FLAG = 'email_requested'.freeze

  pattr_initialize [:conversation!]

  def perform
    ActiveRecord::Base.transaction do
      # Flag first: the hook runs again for the template message itself and
      # must see that the email was already asked for.
      conversation.update!(additional_attributes: conversation.additional_attributes.merge(REQUESTED_FLAG => true))
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
