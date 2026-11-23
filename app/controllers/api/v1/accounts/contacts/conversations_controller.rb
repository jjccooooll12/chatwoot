class Api::V1::Accounts::Contacts::ConversationsController < Api::V1::Accounts::Contacts::BaseController
  RESULTS_PER_PAGE = 20

  def index
    # Start with all conversations for this contact
    conversations = Current.account.conversations.includes(
      :assignee, :contact, :inbox, :taggings
    ).where(contact_id: @contact.id)

    # Apply permission-based filtering using the existing service
    conversations = Conversations::PermissionFilterService.new(
      conversations,
      Current.user,
      Current.account
    ).perform

    @current_page = [params[:page].to_i, 1].max
    @conversations = conversations.order(last_activity_at: :desc, id: :desc)
                                  .offset((@current_page - 1) * RESULTS_PER_PAGE)
                                  .limit(RESULTS_PER_PAGE + 1).to_a
    @has_more = @conversations.size > RESULTS_PER_PAGE
    @conversations = @conversations.first(RESULTS_PER_PAGE)
  end
end
