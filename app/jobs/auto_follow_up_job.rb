class AutoFollowUpJob < ApplicationJob
  queue_as :scheduled_jobs

  # Scans pending conversations that have auto follow-up switched on and lets the
  # service decide whether to nudge the customer or reopen the ticket for a human.
  def perform
    Conversation.where(status: :pending)
                .where("conversations.custom_attributes->>'freshdesk_auto_follow_up' = 'yes'")
                .find_each do |conversation|
      Conversations::AutoFollowUpService.new(conversation: conversation).perform
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: conversation.account).capture_exception
    end
  end
end
