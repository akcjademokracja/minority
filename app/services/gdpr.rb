class Member
  class GDPR
    def self.optout(member, reason)
      Subscription.all.each do |channel| 
        member.unsubscribe_from(channel, reason)
      end
    end

    def self.forget(member)
      if member.admin
        return false
      end

      member.unsubscribe_permanently

      last_year_donations = member.donations.where("created_at > ?", Date.today - 1.year)

      regular_donations = member.regular_donations
      if last_year_donations.count == 0 and regular_donations.count == 0
        member.delete
        return true
      else
        return false
      end
    end
  end
end
