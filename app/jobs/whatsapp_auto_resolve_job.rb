# WhatsApp has no staleness rule of its own — unlike the live-chat widget
# (see STALE_CONVERSATION_WINDOW in Api::V1::Widget::BaseController),
# Twilio::IncomingMessageService just reuses the contact's last non-resolved
# WhatsApp conversation no matter how old it is. Resolving it here after a
# period of inactivity is what makes the *next* inbound message start a
# fresh ticket instead of reopening a months-old one — reusing the same
# resolvable_all scope/toggle_status the stock account-wide auto-resolve
# feature uses, just scoped to WhatsApp inboxes only and run on its own
# schedule (the account-wide feature is off and not on the cron schedule).
class WhatsappAutoResolveJob < ApplicationJob
  queue_as :scheduled_jobs

  STALE_AFTER = 48.hours

  def perform
    return if whatsapp_inbox_ids.empty?

    Conversation.where(inbox_id: whatsapp_inbox_ids)
                .resolvable_all(STALE_AFTER / 1.minute)
                .find_each(&:toggle_status)
  end

  private

  def whatsapp_inbox_ids
    twilio_whatsapp_ids = Channel::TwilioSms.where(medium: 'whatsapp').joins(:inbox).pluck('inboxes.id')
    native_whatsapp_ids = Inbox.where(channel_type: 'Channel::Whatsapp').pluck(:id)
    twilio_whatsapp_ids + native_whatsapp_ids
  end
end
