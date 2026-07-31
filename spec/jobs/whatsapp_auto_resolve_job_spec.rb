require 'rails_helper'

RSpec.describe WhatsappAutoResolveJob do
  let(:account) { create(:account) }
  let(:whatsapp_channel) { create(:channel_twilio_sms, :whatsapp, account: account) }
  let(:whatsapp_inbox) { whatsapp_channel.inbox }
  let(:email_inbox) { create(:channel_email, account: account).inbox }

  def open_conversation_with_activity(inbox, last_activity_at:)
    create(:conversation, account: account, inbox: inbox, status: :open).tap do |conversation|
      conversation.update_column(:last_activity_at, last_activity_at) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  it 'resolves an open WhatsApp conversation idle for more than 48h' do
    conversation = open_conversation_with_activity(whatsapp_inbox, last_activity_at: 49.hours.ago)

    described_class.new.perform

    expect(conversation.reload.status).to eq('resolved')
  end

  it 'leaves a recently active WhatsApp conversation open' do
    conversation = open_conversation_with_activity(whatsapp_inbox, last_activity_at: 1.hour.ago)

    described_class.new.perform

    expect(conversation.reload.status).to eq('open')
  end

  # Regression: this job must stay scoped to WhatsApp inboxes only - it must
  # never reach for the stock account-wide auto-resolve behavior, which would
  # also resolve stale Email/Voice tickets nobody asked to have auto-resolved.
  it 'does not touch a stale conversation on a non-WhatsApp inbox' do
    conversation = open_conversation_with_activity(email_inbox, last_activity_at: 49.hours.ago)

    described_class.new.perform

    expect(conversation.reload.status).to eq('open')
  end
end
