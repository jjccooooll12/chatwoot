class AllowDetachedOutboundVoiceCalls < ActiveRecord::Migration[7.1]
  def change
    change_column_null :voice_calls, :conversation_id, true
  end
end
