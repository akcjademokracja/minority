class GhostbusterWorker
  include Sidekiq::Worker

  def perform
    Member.all.each do |m|
      # Can't anonymize any donators, really.
      # Also not anonymizing subscribed people.
      next if m.donations.count >= 1 or m.subscribed?

      # If there are no member_actions with member_action_consents of public_id 'gdpr_campaign_1.0' and and campaign that is not finished, ghost the member.
      GhostMemberWorker.perform_async(m.id) if m.member_actions.joins(member_action_consents: :consent_text)
                                                               .where(member_action_consents: { consent_texts: { public_id: 'gdpr_campaign_1.0' } })
                                                               .joins(action: :campaign)
                                                               .where(action: { campaigns: { finished_at: nil } })
                                                               .empty? 
    end
  end
end