# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Conversations::MergeService do
  subject(:service) do
    described_class.new(
      account: account,
      primary_conversation: primary_conversation,
      secondary_conversation: secondary_conversation,
      user: user
    )
  end

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, :with_email, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:primary_conversation) do
    create(
      :conversation,
      account: account,
      inbox: inbox,
      contact: contact,
      contact_inbox: contact_inbox,
      status: :pending,
      additional_attributes: { 'ticket_number' => '2607271' }
    )
  end
  let(:secondary_conversation) do
    create(
      :conversation,
      account: account,
      inbox: inbox,
      contact: contact,
      contact_inbox: contact_inbox,
      status: :open,
      additional_attributes: { 'ticket_number' => '2607272' }
    )
  end

  it 'closes the secondary ticket and keeps the primary ticket status unchanged' do
    service.perform

    expect(primary_conversation.reload.status).to eq('pending')
    expect(secondary_conversation.reload.status).to eq('resolved')
  end

  it 'records merge metadata and cross-linked activity messages' do
    service.perform

    primary_activity = primary_conversation.reload.messages.activity.last
    secondary_activity = secondary_conversation.reload.messages.activity.last

    expect(primary_conversation.additional_attributes['merged_ticket_numbers']).to include('2607272')
    expect(secondary_conversation.additional_attributes['merged_into_ticket_number']).to eq('2607271')
    expect(primary_activity.content_attributes.dig('activity', 'type')).to eq('conversation_merged')
    expect(primary_activity.content).to include('/conversations/')
    expect(primary_activity.content).to include('#2607272')
    expect(secondary_activity.content_attributes.dig('activity', 'type')).to eq('conversation_merged')
    expect(secondary_activity.content).to include('#2607271')
  end
end
