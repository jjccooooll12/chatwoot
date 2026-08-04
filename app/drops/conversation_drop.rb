class ConversationDrop < BaseDrop
  include MessageFormatHelper

  def id
    @obj.try(:display_id)
  end

  def display_id
    @obj.try(:display_id)
  end

  # Customer-facing ticket number (yymmdd + daily counter). Templates should
  # always render this rather than display_id, so every surface quotes the same
  # identifier the agent UI and outgoing email subjects use.
  def ticket_number
    @obj.try(:ticket_number)
  end

  def contact_name
    @obj.try(:contact).name.try(:capitalize) || 'Customer'
  end

  def recent_messages
    @obj.try(:recent_messages).map do |message|
      {
        'sender' => message_sender_name(message.sender),
        'content' => render_message_content(transform_user_mention_content(message.content)),
        'attachments' => message.attachments.map(&:file_url)
      }
    end
  end

  def custom_attribute
    custom_attributes = @obj.try(:custom_attributes) || {}
    custom_attributes.transform_keys(&:to_s)
  end

  private

  def message_sender_name(sender)
    return 'Bot' if sender.blank?
    return contact_name if sender.instance_of?(Contact)

    sender&.available_name || sender&.name
  end
end
