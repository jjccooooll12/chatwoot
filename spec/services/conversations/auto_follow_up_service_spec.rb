# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Conversations::AutoFollowUpService do
  subject(:service) { described_class.new(conversation: conversation) }

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, status: :pending,
                          custom_attributes: { 'freshdesk_auto_follow_up' => 'yes' })
  end
  let(:nudges) { conversation.messages.where("messages.additional_attributes->>'auto_follow_up_nudge' = 'true'") }

  it 'nudges once 24h have passed since the only agent reply' do
    travel_to(25.hours.ago) { create(:message, conversation: conversation, account: account, inbox: inbox, sender: agent, message_type: :outgoing) }

    expect { service.perform }.to change(nudges, :count).by(1)
  end

  # Regression: Message's default scope sorts ascending, so the "last" reply
  # resolved to the FIRST one and a nudge went out minutes after a fresh reply.
  it 'measures the 24h from the latest agent reply, not the first' do
    travel_to(26.hours.ago) { create(:message, conversation: conversation, account: account, inbox: inbox, sender: agent, message_type: :outgoing) }
    travel_to(20.minutes.ago) { create(:message, conversation: conversation, account: account, inbox: inbox, sender: agent, message_type: :outgoing) }

    expect { service.perform }.not_to change(nudges, :count)
  end
end
