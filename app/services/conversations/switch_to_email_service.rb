# frozen_string_literal: true

# Moves a non-email conversation (live chat, voice call, ...) onto the
# account's email inbox, in place — same conversation/ticket, but from this
# point on it goes through the normal email reply/threading pipeline (so a
# customer reply lands back in this same ticket) instead of the original
# channel's delivery mechanism.
class Conversations::SwitchToEmailService
  pattr_initialize [:conversation!, :email!, :user]

  class NotSwitchableToEmail < StandardError; end

  def perform
    raise NotSwitchableToEmail if conversation.inbox.channel_type == 'Channel::Email'

    ActiveRecord::Base.transaction do
      update_contact_email!
      conversation.update!(inbox_id: email_inbox.id, contact_inbox_id: email_contact_inbox.id)
      create_switch_activity!
    end

    conversation
  end

  private

  def normalized_email
    @normalized_email ||= email.to_s.downcase.strip
  end

  def update_contact_email!
    return if contact.email.to_s.casecmp(normalized_email).zero?

    contact.update!(email: normalized_email)
  end

  def contact
    @contact ||= conversation.contact
  end

  def email_inbox
    @email_inbox ||= conversation.account.inboxes.find_by!(channel_type: 'Channel::Email')
  end

  def email_contact_inbox
    # source_id is a required kwarg on ContactInboxBuilder with no default —
    # pass nil explicitly so it self-derives one from contact.email.
    @email_contact_inbox ||= ContactInboxBuilder.new(contact: contact, inbox: email_inbox, source_id: nil).perform
  end

  def create_switch_activity!
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      content: I18n.t('conversations.activity.switched_to_email', user_name: user&.name || 'System', email: normalized_email),
      content_attributes: {
        activity: {
          type: 'conversation_switched_to_email',
          email: normalized_email,
          performed_by: user&.name
        }.compact
      }
    )
  end
end
