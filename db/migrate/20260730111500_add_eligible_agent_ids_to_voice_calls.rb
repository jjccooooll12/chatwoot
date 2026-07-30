class AddEligibleAgentIdsToVoiceCalls < ActiveRecord::Migration[7.1]
  def change
    # nil/empty means "no country route matched — every online inbox member
    # is eligible" (fail open); a present array is the enforced allow-list,
    # checked both when deciding who to ring and when an agent tries to answer.
    add_column :voice_calls, :eligible_agent_ids, :jsonb, default: [], null: false
  end
end
