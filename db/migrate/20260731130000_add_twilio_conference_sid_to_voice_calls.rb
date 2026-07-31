class AddTwilioConferenceSidToVoiceCalls < ActiveRecord::Migration[7.1]
  def change
    add_column :voice_calls, :twilio_conference_sid, :string
    add_index :voice_calls, :twilio_conference_sid
  end
end
