class CreateVoiceCalls < ActiveRecord::Migration[7.1]
  def change
    create_table :voice_calls do |t|
      t.bigint :account_id, null: false
      t.bigint :inbox_id, null: false
      t.bigint :conversation_id, null: false
      t.bigint :contact_id, null: false
      t.bigint :message_id
      t.bigint :accepted_by_agent_id
      t.string :provider_call_id, null: false
      t.string :direction, null: false, default: 'incoming'
      t.string :status, null: false, default: 'ringing'
      t.string :conference_sid
      t.string :from_number
      t.string :to_number
      t.string :end_reason
      t.datetime :started_at
      t.datetime :ended_at
      t.integer :duration_seconds

      t.timestamps
    end

    add_index :voice_calls, :provider_call_id, unique: true
    add_index :voice_calls, [:account_id, :conversation_id]
    add_index :voice_calls, :message_id
  end
end
