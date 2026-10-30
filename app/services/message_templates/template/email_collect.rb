# Peach Labels: one friendly bot message asking for an email, answered in plain
# text — instead of upstream's "Give the team a way to reach you." plus an
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
      conversation.messages.create!(email_request_message_params)
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: conversation.account).capture_exception
    true
  end

  private

  def email_request_message_params
    {
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :template,
      content: I18n.t('conversations.templates.email_request_message_body')
    }
  end
end
