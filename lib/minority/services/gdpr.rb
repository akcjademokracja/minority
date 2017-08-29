class Member
  class GDPR
    def self.optout(member, reason)
      Subscription.all.each do |channel| 
        member.unsubscribe_from(channel, reason)
      end
    end
  end
end
