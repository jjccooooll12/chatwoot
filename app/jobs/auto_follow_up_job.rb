class AutoFollowUpJob < ApplicationJob
  queue_as :scheduled_jobs

  # Every pending conversation has a reopen deadline. The per-ticket auto-follow-up
  # switch only controls customer nudges; it must not strand a ticket in Pending.
  def perform
    Conversation.where(status: :pending).find_each do |conversation|
      Conversations::AutoFollowUpService.new(conversation: conversation).perform
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: conversation.account).capture_exception
    end
  end
end
