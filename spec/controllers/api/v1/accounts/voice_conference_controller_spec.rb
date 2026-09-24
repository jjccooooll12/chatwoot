require 'rails_helper'

RSpec.describe 'Voice Conference API', type: :request do
  let(:account) { create(:account) }
  let(:channel) do
    create(:channel_api, account: account,
                         additional_attributes: { twilio_account_sid: 'AC_test', twilio_twiml_app_sid: 'AP_test', twilio_api_key_sid: 'SK_test' })
  end
  let(:inbox) { channel.inbox }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let!(:voice_call) do
    create(:voice_call, account: account, inbox: inbox, conversation: conversation, contact: conversation.contact, provider_call_id: 'CA_join_1')
  end

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_member, inbox: inbox, user: other_agent)
  end

  around do |example|
    with_modified_env(TWILIO_VOICE_API_KEY_SECRET: 'secret') { example.run }
  end

  describe 'GET /inboxes/:inbox_id/conference/token' do
    it 'is unauthorized for agents not on the inbox' do
      outsider = create(:user, account: account, role: :agent)

      get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/conference/token", headers: outsider.create_new_auth_token

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns a Twilio access token for an inbox member' do
      get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/conference/token", headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['token']).to be_present
      expect(body['account_id']).to eq(account.id)
    end
  end

  describe 'POST /inboxes/:inbox_id/conference' do
    it 'lets the first agent claim the call' do
      post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/conference",
           params: { conversation_id: conversation.display_id, call_sid: 'CA_join_1' }, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['conference_sid']).to eq(voice_call.conference_sid)
      expect(voice_call.reload.accepted_by_agent_id).to eq(agent.id)
    end

    # Regression: the ring can time out (or the caller can hang up) in the
    # window between the popup rendering and an agent clicking Answer. Without
    # this check, that race silently "succeeded" - accepted_by_agent_id got
    # set on a call already resolved as no_answer, a confusing, wrong state.
    it 'returns 409 when the call already timed out to voicemail before the agent claimed it' do
      voice_call.update!(status: 'no_answer', ended_at: Time.current, end_reason: 'no_answer')

      post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/conference",
           params: { conversation_id: conversation.display_id, call_sid: 'CA_join_1' }, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:conflict)
      expect(voice_call.reload.accepted_by_agent_id).to be_nil
    end

    it 'returns 409 for a second agent trying to claim an already-answered call' do
      voice_call.update!(accepted_by_agent_id: agent.id)

      post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/conference",
           params: { conversation_id: conversation.display_id, call_sid: 'CA_join_1' }, headers: other_agent.create_new_auth_token

      expect(response).to have_http_status(:conflict)
    end

    it 'is idempotent for the agent who already claimed it' do
      post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/conference",
           params: { conversation_id: conversation.display_id, call_sid: 'CA_join_1' }, headers: agent.create_new_auth_token
      post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/conference",
           params: { conversation_id: conversation.display_id, call_sid: 'CA_join_1' }, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
    end

    it 'assigns the conversation to the agent who answers' do
      post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/conference",
           params: { conversation_id: conversation.display_id, call_sid: 'CA_join_1' }, headers: agent.create_new_auth_token

      expect(conversation.reload.assignee_id).to eq(agent.id)
    end

    it 'does not steal an already-assigned conversation from another agent' do
      conversation.update!(assignee_id: other_agent.id)

      post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/conference",
           params: { conversation_id: conversation.display_id, call_sid: 'CA_join_1' }, headers: agent.create_new_auth_token

      expect(conversation.reload.assignee_id).to eq(other_agent.id)
    end

    it 'rejects an agent excluded by a country-routing rule even though they are an inbox member' do
      voice_call.update!(eligible_agent_ids: [other_agent.id])

      post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/conference",
           params: { conversation_id: conversation.display_id, call_sid: 'CA_join_1' }, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:forbidden)
      expect(voice_call.reload.accepted_by_agent_id).to be_nil
    end

    it 'lets the routed agent claim a country-restricted call' do
      voice_call.update!(eligible_agent_ids: [agent.id])

      post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/conference",
           params: { conversation_id: conversation.display_id, call_sid: 'CA_join_1' }, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(voice_call.reload.accepted_by_agent_id).to eq(agent.id)
    end
  end

  describe 'DELETE /inboxes/:inbox_id/conference' do
    let(:twilio_hangup_url) { 'https://api.twilio.com/2010-04-01/Accounts/AC_test/Calls/CA_join_1.json' }

    it 'hangs up the Twilio call and completes the voice call' do
      hangup = stub_request(:post, twilio_hangup_url).with(body: { 'Status' => 'completed' }).to_return(status: 200, body: '{}')

      delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/conference",
             params: { conversation_id: conversation.display_id, call_sid: 'CA_join_1' }, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(hangup).to have_been_requested
      expect(voice_call.reload).to be_completed
      expect(voice_call.end_reason).to eq('agent_hangup')
    end

    it 'still completes the call when Twilio says it already ended' do
      stub_request(:post, twilio_hangup_url).to_return(status: 404, body: { code: 20_404, message: 'Not found' }.to_json)

      delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/conference",
             params: { conversation_id: conversation.display_id, call_sid: 'CA_join_1' }, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(voice_call.reload).to be_completed
    end
  end
end
