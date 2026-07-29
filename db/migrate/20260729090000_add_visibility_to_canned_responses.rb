class AddVisibilityToCannedResponses < ActiveRecord::Migration[7.1]
  def up
    # Same personal/global convention as Macro (app/models/macro.rb) — mirrored
    # deliberately so canned responses get identical "mine vs the whole team's"
    # semantics without inventing a second pattern.
    add_column :canned_responses, :visibility, :integer, default: 0, null: false
    add_column :canned_responses, :created_by_id, :bigint
    add_column :canned_responses, :updated_by_id, :bigint

    # Every response that already existed was implicitly shared with the whole
    # account (there was no personal/global concept before this migration) —
    # backfill to global so they don't vanish from everyone's list once
    # CannedResponse.with_visibility scoping goes live.
    execute 'UPDATE canned_responses SET visibility = 1'
  end

  def down
    remove_column :canned_responses, :updated_by_id
    remove_column :canned_responses, :created_by_id
    remove_column :canned_responses, :visibility
  end
end
