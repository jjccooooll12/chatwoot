require 'rails_helper'

RSpec.describe VoiceRecordingDownloadJob do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_api, account: account, additional_attributes: { twilio_account_sid: 'AC_test' }) }
  let(:inbox) { channel.inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) do
    create(:message, account: account, conversation: conversation, sender: conversation.contact,
                      content_type: :voice_call, content: 'Incoming call')
  end
  let(:recording_url) { 'https://api.twilio.com/2010-04-01/Accounts/AC_test/Recordings/RE1' }

  around do |example|
    with_modified_env(TWILIO_VOICE_AUTH_TOKEN: 'test_auth_token') { example.run }
  end

  before do
    stub_request(:get, "#{recording_url}.wav").to_return(status: 200, body: 'fake-audio-bytes')
  end

  context 'when the call never got answered (voicemail)' do
    let(:voice_call) do
      create(:voice_call, account: account, inbox: inbox, conversation: conversation, contact: conversation.contact,
                           message: message, status: 'no_answer', provider_call_id: 'CA_voicemail')
    end

    it 'attaches the recording and finalizes the outcome as a voicemail' do
      described_class.perform_now(voice_call.id, recording_url)

      expect(voice_call.reload.recording).to be_attached
      expect(message.reload.content).to eq('Voicemail')
    end
  end

  context 'when the call is still ringing when the recording lands' do
    let(:voice_call) do
      create(:voice_call, account: account, inbox: inbox, conversation: conversation, contact: conversation.contact,
                           message: message, status: 'ringing', provider_call_id: 'CA_ringing')
    end

    it 'settles the call as no_answer and finalizes it as a voicemail' do
      described_class.perform_now(voice_call.id, recording_url)

      expect(voice_call.reload.status).to eq('no-answer')
      expect(message.reload.content).to eq('Voicemail')
    end
  end

  context 'when the recording is from an answered call (conference recording)' do
    let(:voice_call) do
      create(:voice_call, account: account, inbox: inbox, conversation: conversation, contact: conversation.contact,
                           message: message, status: 'completed', provider_call_id: 'CA_answered')
    end

    it 'attaches the recording but does not relabel the ticket as a voicemail' do
      described_class.perform_now(voice_call.id, recording_url)

      expect(voice_call.reload.recording).to be_attached
      expect(message.reload.content).to eq('Incoming call')
    end
  end

  context 'when Twilio has not made the recording available yet' do
    let(:voice_call) do
      create(:voice_call, account: account, inbox: inbox, conversation: conversation, contact: conversation.contact,
                           message: message, status: 'no_answer', provider_call_id: 'CA_pending')
    end

    before { stub_request(:get, "#{recording_url}.wav").to_return(status: 404) }

    it 're-enqueues instead of dropping the recording' do
      expect do
        described_class.perform_now(voice_call.id, recording_url)
      end.to have_enqueued_job(described_class).with(voice_call.id, recording_url)

      expect(voice_call.reload.recording).not_to be_attached
    end
  end

  it 'stores the lossless WAV original' do
    voice_call = create(:voice_call, account: account, inbox: inbox, conversation: conversation, contact: conversation.contact,
                                     message: message, status: 'completed', provider_call_id: 'CA_wav')

    described_class.perform_now(voice_call.id, recording_url)

    expect(voice_call.reload.recording.content_type).to eq('audio/wav')
  end
end
