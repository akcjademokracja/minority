class FreshDeskRateLimitHit < StandardError
    def initialize(retry_after)
        super("FreshDesk rate limit hit! New API credits available in #{retry_after/60} minutes.")
    end
end  

class FreshDeskError < StandardError
    def initialize(message)
        super(message)
    end
end

class AortaCheckTicketWorker
    #include Sidekiq::Worker

    def self.perform(ticket_id)
        auth = {:username => ENV['FRESHDESK_API_TOKEN'], :password => "X"}
        # Cost: 2 FreshDesk API credits
        response = HTTParty.get("https://#{ENV["FRESHDESK_DOMAIN"]}.freshdesk.com/api/v2/tickets/#{ticket_id.to_i}?include=requester", :basic_auth => auth)
        result = {email: response["requester"]["email"], requester_id: response["requester"]["requester_id"] subject: response["subject"], type: response["type"], tags: response["tags"]}

        # Throw an exception upon hitting the rate limit
        if response.response["x-ratelimit-remaining"] < 2 or response.response["code"] == 429
            raise FreshDeskRateLimitHit(response.response["retry-after"])
        elsif response.response["code"] != 200
            raise FreshDeskError("Something went wrong! Status code: #{response.response["code"]}")
        end
            
        new_tags = []
        
        unless result[:tags].include? "aorta_processed"
            p "Not processed!"

            # Now we know who we're dealing with
            member = Member.find_by(email: result[:email])

            if result[:type] == "Wypisanie"
                p "Wypiszcie mnie!"
                Member::GDPR.optout(member, "Aorta opt-out") if member
                new_tags << "wypisano"
            end

            if result[:type] == "Usunięcie danych"
                p "Usuńcie mnie!"
                # Not implemented yet
                #Member::GDPR.forget(member, reason) if member
                new_tags << "zapomniano"
            end

            unless result[:subject].scan(/^(odp|sv|re): (.+)/i).empty?
                p "It's a reply, checking campaign names."
                result[:subject].gsub!(/^(odp|sv|re): /i, '')

                # Now we have to get mailings with that subject and extract campaign names from them
                # Then, we assign these campaign names to FreshDesk tickets as tags
                mailings_ids = Mailing.joins(:test_cases).
                                   where("mailing_test_cases.template LIKE ?", "%#{result[:subject]}%").
                                   select('DISTINCT mailings.id').pluck(:id)

                # Array of Mailing objects
                mailings_by_tags = Mailing.where(id: mailings_ids)

                # Extract the campaign names
                mailings_by_tags_campaigns = mailings_by_tags.map {|mailing| mailing.name.split("-")[0]}

                # Array of Mailing objects
                mailings_by_subject = Mailing.find_by(subject: result[:subject])

                # Extract the campaign names
                mailings_by_subject_campaigns = mailings_by_subject.map {|mailing| mailing.name.split("-")[0]}

                # Add campaign names to tags
                new_tags = new_tags + (mailings_by_tags_campaigns + mailings_by_subject_campaigns).uniq
            else
                p "It's not a reply. Proceeding to watchdog operation."
            end

            # Now that we have campaign names, time to get watchdog data and send it to FreshDesk
            # If someone's "unsubscribed_at" is nil it probably means they're subscribed
            # Example unsubbed member: 523713
            # Get all unsubs with: MemberSubscription.where("member_subscriptions.unsubscribed_at IS NOT ?", nil).to_a
            if member
                is_member_subscribed = !MemberSubscription.where(member_id: member.id).first.unsubscribed_at
                member_description = "aorta-ruby v0.0.8; donated: #{member.donations_count} times; highest: #{member.highest_donation}, subscribed: #{is_member_subscribed}"
                # Cost: 1 FreshDesk API credit
                fd_requester_update_status = fd_update_requester_info(member_description)
                puts "Requester description update failed! FreshDesk returned #{fd_requester_update_status}." unless fd_requester_update_status == 200
            else
                member_description = "aorta-ruby v0.0.8; no person by that email in Identity"
                # Save 1 API call by not sending that to FreshDesk
                fd_requester_update_status = fd_update_requester_info(member_description)
                puts "Requester description update failed! FreshDesk returned #{fd_requester_update_status}." unless fd_requester_update_status == 200
            end

            # Update the ticket's tags at the end
            # Cost: 1 FreshDesk API credit
            new_tags << "aorta_processed"
            fd_ticket_tag_update_status = fd_update_ticket_tags(new_tags)
            puts "Ticket tag update failed! FreshDesk returned #{fd_ticket_update_status}." unless fd_ticket_tag_update_status == 200
        end
    end

    def fd_update_requester_info(new_member_description)
        response = HTTParty.put("https://#{ENV["FRESHDESK_DOMAIN"]}.freshdesk.com/api/v2/contacts/#{requester_id.to_i}", headers: { 'Content-Type' => 'application/json' }, basic_auth: auth, body: {description: member_description}.to_json)
        if response.response["x-ratelimit-remaining"] < 2 or response.response["code"] == 429
            raise FreshDeskRateLimitHit(response.response["retry-after"])
        elsif response.response["code"] != 200
            raise FreshDeskError("Something went wrong! Status code: #{response.response["code"]}")
        end
        return response.response["code"]
    end

    def fd_update_ticket_tags(new_tags)
        response = HTTParty.put("https://#{ENV["FRESHDESK_DOMAIN"]}.freshdesk.com/api/v2/tickets/#{ticket_id.to_i}", headers: { 'Content-Type' => 'application/json' }, basic_auth: auth, body: {tags: new_tags}.to_json)
        if response.response["x-ratelimit-remaining"] < 2 or response.response["code"] == 429
            raise FreshDeskRateLimitHit(response.response["retry-after"])
        elsif response.response["code"] != 200
            raise FreshDeskError("Something went wrong! Status code: #{response.response["code"]}")
        end
        return response.response["code"]
    end

end