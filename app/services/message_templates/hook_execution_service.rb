class MessageTemplates::HookExecutionService
  pattr_initialize [:message!]

  def perform
    return if conversation.last_incoming_message.blank?
    return if message.auto_reply_email?

    capture_email_from_message
    trigger_templates
  end

  private

  delegate :inbox, :conversation, to: :message
  delegate :contact, to: :conversation

  # Peach Labels: the widget asks for an email in plain text (EmailCollect), so
  # the visitor types it into a normal message. Save it on the contact the
  # same way the widget's email input box did (merging into an existing
  # contact with that email), then confirm.
  EMAIL_IN_TEXT = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i

  def capture_email_from_message
    return unless should_capture_email?

    email = message.content.to_s[EMAIL_IN_TEXT]&.downcase
    return if email.blank?

    ContactIdentifyAction.new(contact: contact, params: { email: email }, retain_original_contact_name: true).perform
    conversation.reload
    return unless email_collect_was_sent?

    conversation.messages.create!(email_received_message_params)
  rescue ActiveRecord::RecordInvalid => e
    # Text that looks like an email but fails Contact's email validation must
    # not fail the visitor's message; the request stays open for a real one.
    ChatwootExceptionTracker.new(e, account: conversation.account).capture_exception
  end

  def should_capture_email?
    message.incoming? && inbox.web_widget? && !contact_has_email?
  end

  def email_received_message_params
    {
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :template,
      content: I18n.t('conversations.templates.email_received_message_body')
    }
  end

  def trigger_templates
    ::MessageTemplates::Template::OutOfOffice.new(conversation: conversation).perform if should_send_out_of_office_message?
    ::MessageTemplates::Template::Greeting.new(conversation: conversation).perform if should_send_greeting?
    ::MessageTemplates::Template::EmailCollect.new(conversation: conversation).perform if inbox.enable_email_collect && should_send_email_collect?
  end

  def should_send_out_of_office_message?
    return false if conversation.campaign.present?
    # should not send if its a tweet message
    return false if conversation.tweet?
    # should not send for outbound messages
    return false unless message.incoming?
    # prevents sending out-of-office message if an agent has sent a message in last 5 minutes
    # ensures better UX by not interrupting active conversations at the end of business hours
    return false if conversation.messages.outgoing.where(private: false).exists?(['created_at > ?', 5.minutes.ago])

    inbox.out_of_office? && conversation.messages.today.template.empty? && inbox.out_of_office_message.present?
  end

  def first_message_from_contact?
    conversation.messages.outgoing.count.zero? && conversation.messages.template.count.zero?
  end

  def should_send_greeting?
    return false if conversation.campaign.present?
    # should not send if its a tweet message
    return false if conversation.tweet?

    first_message_from_contact? && inbox.greeting_enabled? && inbox.greeting_message.present?
  end

  def email_collect_was_sent?
    conversation.additional_attributes[MessageTemplates::Template::EmailCollect::REQUESTED_FLAG].present? ||
      conversation.messages.where(content_type: 'input_email').present?
  end

  # TODO: we should be able to reduce this logic once we have a toggle for email collect messages
  def should_send_email_collect?
    return false if conversation.campaign.present?

    !contact_has_email? && inbox.web_widget? && !email_collect_was_sent?
  end

  def contact_has_email?
    contact.email
  end
end
MessageTemplates::HookExecutionService.prepend_mod_with('MessageTemplates::HookExecutionService')
