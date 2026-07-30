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
  end

  describe 'DELETE /inboxes/:inbox_id/conference' do
    it 'returns ok' do
      delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/conference",
             params: { conversation_id: conversation.display_id, call_sid: 'CA_join_1' }, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
    end
  end
end
