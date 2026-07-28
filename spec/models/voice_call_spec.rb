require 'rails_helper'

RSpec.describe VoiceCall do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_api, account: account) }
  let(:inbox) { channel.inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) { create(:message, account: account, inbox: inbox, conversation: conversation, content_type: :voice_call) }

  let(:voice_call) do
    described_class.create!(
      account: account,
      inbox: inbox,
      conversation: conversation,
      contact: conversation.contact,
      message: message,
      provider_call_id: 'CA_test_123',
      conference_sid: 'voice-abc123',
      from_number: '+15550001111',
      to_number: '+15550002222'
    )
  end

  it 'defaults to a ringing incoming call' do
    expect(voice_call.status).to eq('ringing')
    expect(voice_call.direction).to eq('incoming')
  end

  it 'requires a unique provider_call_id' do
    voice_call
    duplicate = described_class.new(
      account: account, inbox: inbox, conversation: conversation, contact: conversation.contact,
      provider_call_id: 'CA_test_123'
    )
    expect(duplicate).not_to be_valid
  end

  describe '#push_event_data' do
    it 'returns the exact field set the frontend expects' do
      data = voice_call.push_event_data

      expect(data.keys).to contain_exactly(
        :id, :provider_call_id, :provider, :direction, :status, :duration_seconds, :end_reason,
        :conference_sid, :accepted_by_agent_id, :accepted_by_agent_name, :started_at, :ended_at,
        :from_number, :to_number, :recording_url, :transcript
      )
      expect(data[:status]).to eq('ringing')
      expect(data[:direction]).to eq('incoming')
    end

    it 'includes the recording url once a recording is attached' do
      voice_call.recording.attach(
        io: Rails.root.join('spec/assets/sample.mp3').open, filename: 'sample.mp3', content_type: 'audio/mpeg'
      )
      expect(voice_call.push_event_data[:recording_url]).to be_present
    end
  end

  describe '#transition_to!' do
    it 'updates status/attrs and fires the message update event' do
      expect(message).to receive(:send_update_event)

      voice_call.transition_to!(status: 'in_progress', started_at: Time.current)

      expect(voice_call.reload.status).to eq('in-progress')
    end

    it 'is a no-op on the message side when there is no linked message' do
      voice_call.update!(message: nil)
      expect { voice_call.transition_to!(status: 'failed', end_reason: 'busy') }.not_to raise_error
    end
  end
end
