class Imap::ImapMailbox
  include MailboxHelper
  include IncomingEmailValidityHelper
  attr_accessor :channel, :account, :inbox, :conversation, :processed_mail

  FALLBACK_CONVERSATION_PATTERN = %r{account/(\d+)/conversation/([a-zA-Z0-9-]+)@}

  # Inbound emails from these senders never become (or merge into) a ticket — they
  # are automated notifications, not customer conversations. A domain entry also
  # matches its subdomains; an entry with "@" matches an exact address. The team
  # can extend this at runtime via account.custom_attributes['blocked_ticket_senders'].
  DEFAULT_BLOCKED_SENDER_DOMAINS = %w[microsoft.com godaddy.com].freeze

  def process(mail, channel)
    @inbound_mail = mail
    @channel = channel
    load_account
    load_inbox
    decorate_mail

    Rails.logger.info("Processing Email from: #{@processed_mail.original_sender} : inbox #{@inbox.id} : message_id #{@processed_mail.message_id}")

    # Skip processing email if it belongs to any of the edge cases
    return unless incoming_email_from_valid_email?

    if blocked_sender?
      Rails.logger.info("[ImapMailbox] Skipped filtered sender #{@processed_mail.original_sender} (no ticket created)")
      return
    end

    ActiveRecord::Base.transaction do
      find_or_create_contact
      find_or_create_conversation
      create_message
      add_attachments_to_message
    end
  end

  private

  def load_account
    @account = @channel.account
  end

  def load_inbox
    @inbox = @channel.inbox
  end

  def decorate_mail
    @processed_mail = MailPresenter.new(@inbound_mail, @account)
  end

  def blocked_sender?
    sender = original_sender_email.to_s.downcase.strip
    return false if sender.blank?

    domain = sender.split('@').last.to_s
    blocked_sender_patterns.any? do |pattern|
      if pattern.include?('@')
        sender == pattern
      else
        domain == pattern || domain.end_with?(".#{pattern}")
      end
    end
  end

  def blocked_sender_patterns
    custom = Array(@account.custom_attributes['blocked_ticket_senders'])
    (DEFAULT_BLOCKED_SENDER_DOMAINS + custom).map { |pattern| pattern.to_s.downcase.strip }.reject(&:blank?).uniq
  end

  def find_conversation_by_in_reply_to
    return if in_reply_to.blank?

    message = @inbox.messages.find_by(source_id: in_reply_to)
    if message.nil?
      @inbox.conversations.find_by("additional_attributes->>'in_reply_to' = ?", in_reply_to)
    else
      @inbox.conversations.find(message.conversation_id)
    end
  end

  def find_conversation_by_reference_ids
    return if @inbound_mail.references.blank?

    message = find_message_by_references
    if message.present?
      conversation = @inbox.conversations.find_by(id: message.conversation_id)
      return conversation if conversation.present?
    end

    # FALLBACK_PATTERN use to find a conversation that is started by an agent (no incoming message yet)
    conversation_id = find_conversation_by_references
    @inbox.conversations.find_by(uuid: conversation_id) if conversation_id.present?
  end

  def in_reply_to
    sanitize_mailbox_value(@processed_mail.in_reply_to)
  end

  def find_conversation_by_references
    references.each do |message_id|
      match = FALLBACK_CONVERSATION_PATTERN.match(message_id)

      return match[2] if match.present?
    end
  end

  def find_message_by_references
    message_to_return = nil

    references.each do |message_id|
      message = @inbox.messages.find_by(source_id: message_id)
      message_to_return = message if message.present?
    end
    message_to_return
  end

  # Merge an inbound email into an existing ticket when its subject carries the
  # ticket number (e.g. "[#2607261]"), even if it lost its threading headers or
  # is a brand-new email that just references the number.
  def find_conversation_by_ticket_number
    match = Mailbox::ConversationFinderStrategies::TicketNumberStrategy::TICKET_PATTERN.match(@processed_mail.subject.to_s)
    return if match.nil?

    @inbox.conversations.find_by("additional_attributes->>'ticket_number' = ?", match[1])
  end

  def find_or_create_conversation
    @conversation = find_conversation_by_in_reply_to || find_conversation_by_reference_ids ||
                    find_conversation_by_ticket_number || ::Conversation.create!(
      {
        account_id: @account.id,
        inbox_id: @inbox.id,
        contact_id: @contact.id,
        contact_inbox_id: @contact_inbox.id,
        additional_attributes: {
          source: 'email',
          in_reply_to: in_reply_to,
          auto_reply: @processed_mail.auto_reply?,
          mail_subject: sanitize_mailbox_value(@processed_mail.subject),
          initiated_at: {
            timestamp: Time.now.utc
          }
        }
      }
    )
  end

  def find_or_create_contact
    @contact = @inbox.contacts.from_email(original_sender_email)
    if @contact.present?
      @contact_inbox = ContactInbox.find_by(inbox: @inbox, contact: @contact)
    else
      create_contact
    end
  end

  def identify_contact_name
    sanitize_mailbox_value(processed_mail.sender_name || processed_mail.from.first.split('@').first)
  end

  def original_sender_email
    sanitize_mailbox_value(@processed_mail.original_sender)
  end

  def references
    sanitize_mailbox_value(Array.wrap(@inbound_mail.references))
  end
end
