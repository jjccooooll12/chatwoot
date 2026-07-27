class BackfillConversationTicketNumbers < ActiveRecord::Migration[7.1]
  class ConversationRecord < ApplicationRecord
    self.table_name = 'conversations'
  end

  def up
    updated_count = 0

    ConversationRecord.distinct.pluck(:account_id).each do |account_id|
      used_ticket_numbers = existing_ticket_numbers(account_id)
      counters = Hash.new(1)

      conversations_for(account_id).each do |conversation|
        attrs = conversation.additional_attributes || {}
        existing = attrs['ticket_number'].presence
        prefix = conversation.created_at.strftime('%y%m%d')

        if existing.present?
          counters[prefix] = next_counter_for(prefix, existing, counters[prefix])
          next
        end

        ticket_number, counters[prefix] = next_ticket_number(prefix, counters[prefix], used_ticket_numbers)
        attrs = attrs.merge('ticket_number' => ticket_number)
        conversation.update_columns(additional_attributes: attrs)
        used_ticket_numbers[ticket_number] = true
        updated_count += 1
      end
    end

    say("Backfilled #{updated_count} conversation ticket numbers")
  end

  def down; end

  private

  def conversations_for(account_id)
    ConversationRecord
      .where(account_id: account_id)
      .select(:id, :account_id, :created_at, :additional_attributes)
      .order(:created_at, :id)
  end

  def existing_ticket_numbers(account_id)
    ConversationRecord
      .where(account_id: account_id)
      .where("COALESCE(additional_attributes->>'ticket_number', '') != ''")
      .pluck(Arel.sql("additional_attributes->>'ticket_number'"))
      .index_with(true)
  end

  def next_counter_for(prefix, existing, current_counter)
    return current_counter unless existing.start_with?(prefix)

    suffix = existing.delete_prefix(prefix).to_i
    [current_counter, suffix + 1].max
  end

  def next_ticket_number(prefix, counter, used_ticket_numbers)
    candidate = "#{prefix}#{counter}"
    while used_ticket_numbers[candidate]
      counter += 1
      candidate = "#{prefix}#{counter}"
    end

    [candidate, counter + 1]
  end
end
