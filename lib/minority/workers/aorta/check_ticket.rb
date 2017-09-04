require 'httparty'

class AortaCheckTicketWorker
    include Sidekiq::Worker

    def perform(ticket_id)
        ticket_id = ticket_id.to_i
        auth = {username: ENV['FRESHDESK_API_TOKEN'], password: "X"}
        # Cost: 2 FreshDesk API credits
        response = HTTParty.get("https://#{ENV["FRESHDESK_DOMAIN"]}.freshdesk.com/api/v2/tickets/#{ticket_id}?include=requester", basic_auth: auth)

        # Throw an exception upon hitting the rate limit
        if response.response["x-ratelimit-remaining"].to_i < 2 or response.response["status"] == "429"
            raise AortaCheckTicketWorker::FreshDeskRateLimitHit.new(response.response["retry-after"])
        elsif response.response["status"] != "200 OK"
            raise AortaCheckTicketWorker::FreshDeskError.new("Something went wrong! Status: #{response.response["status"]}")
        end

        result = {email: response["requester"]["email"], requester_id: response["requester_id"], subject: response["subject"], type: response["type"], tags: response["tags"]}
            
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

                # BY_TAGS

                # An array of IDs matching the criteria, ex. [101, 102] or an empty array if nothing found
                mailing_ids = Mailing.joins(:test_cases).
                                   where("mailing_test_cases.template LIKE ?", "%#{result[:subject]}%").
                                   select('DISTINCT mailings.id').pluck(:id)

                unless mailing_ids.empty?
                    # This is an array of Mailing objects or an array containing a single Mailing object
                    mailings_by_tags = Mailing.where(id: mailing_ids)
                    mailings_by_tags_campaigns = mailings_by_tags.map {|mailing| mailing.name.split("-")[0]}
                else
                    mailings_by_tags_campaigns = []
                end

                # BY_SUBJECT

                # An array of Mailing objects or an array containing a single Mailing object
                mailings_by_subject = Mailing.where(subject: result[:subject])

                unless mailings_by_subject.empty?
                    mailings_by_subject_campaigns = mailings_by_subject.map {|mailing| mailing.name.split("-")[0]}
                else
                    mailings_by_subject_campaigns = []
                end

                # FINAL OPERATION
                
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
                member_description = "Donated: #{member.donations_count || 0} times; highest: #{member.highest_donation || 0}, subscribed: #{is_member_subscribed}."
                # Cost: 1 FreshDesk API credit
                fd_update_requester_info(auth, result[:requester_id], member_description)
            else
                member_description = "No person by that email in Identity."
                # Save 1 API call by not sending that to FreshDesk
                fd_update_requester_info(auth, result[:requester_id], member_description)
            end

            # Update the ticket's tags at the end
            # Cost: 1 FreshDesk API credit
            new_tags << "aorta_processed"
            fd_update_ticket_tags(auth, ticket_id, new_tags)
        end
    end

    private

    def fd_update_requester_info(auth, requester_id, new_requester_description)
        response = HTTParty.put("https://#{ENV["FRESHDESK_DOMAIN"]}.freshdesk.com/api/v2/contacts/#{requester_id.to_i}", headers: { 'Content-Type' => 'application/json' }, basic_auth: auth, body: {description: new_requester_description}.to_json)
        if response.response["x-ratelimit-remaining"].to_i < 2 or response.response["status"] == "429"
            raise FreshDeskRateLimitHit.new(response.response["retry-after"])
        elsif response.response["status"] != "200 OK"
            raise FreshDeskError.new("Something went wrong! Status: #{response.response["status"]}")
        end
        return response.response["status"]
    end

    def fd_update_ticket_tags(auth, ticket_id, new_tags)
        response = HTTParty.put("https://#{ENV["FRESHDESK_DOMAIN"]}.freshdesk.com/api/v2/tickets/#{ticket_id.to_i}", headers: { 'Content-Type' => 'application/json' }, basic_auth: auth, body: {tags: new_tags}.to_json)
        if response.response["x-ratelimit-remaining"].to_i < 2 or response.response["status"] == "429"
            raise FreshDeskRateLimitHit.new(response.response["retry-after"])
        elsif response.response["status"] != "200 OK"
            raise FreshDeskError.new("Something went wrong! Status: #{response.response["status"]}")
        end
        return response.response["status"]
    end

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

end