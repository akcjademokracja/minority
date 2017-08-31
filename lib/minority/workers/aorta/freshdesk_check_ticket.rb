class AortaFreshdeskCheckTicketWorker
    #include Sidekiq::Worker

    def self.perform(ticket_id)
        auth = {:username => ENV['FRESHDESK_API_TOKEN'], :password => "X"}
        response = HTTParty.get("https://#{ENV["FRESHDESK_DOMAIN"]}.freshdesk.com/api/v2/tickets/#{ticket_id.to_i}?include=requester", :basic_auth => auth)
        result = {email: response["requester"]["email"], requester_id: response["requester"]["requester_id"] subject: response["subject"], type: response["type"], tags: response["tags"]}
        
        unless result[:tags].include? "aorta_processed"
            p "Not processed!"

            # Now we know who we're dealing with
            member = Member.find_by(email: result[:email])

            if result[:type] == "Wypisanie"
                p "Wypiszcie mnie!"
                Member::GDPR.optout(member, "Aorta opt-out")
                return
            end

            if result[:type] == "Usunięcie danych"
                p "Usuńcie mnie!"
                #Member::GDPR.forget(member, reason) - not implemented yet
                return
            end

            unless result[:subject].scan(/^(odp|sv|re): (.+)/i).empty?
                p "It's a reply."
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

                # New campaign names
                campaign_names = (mailings_by_tags_campaigns + mailings_by_subject_campaigns).uniq

                # Now that we have campaign names, time to get watchdog data and send it to FreshDesk
                # If someone's "unsubscribed_at" is nil it probably means they're subscribed
                # Example unsubbed member: 523713
                # Get all unsubs with: MemberSubscription.where("member_subscriptions.unsubscribed_at IS NOT ?", nil).to_a
                is_member_subscribed = !MemberSubscription.where(member_id: member.id).first.unsubscribed_at
                member_description = "aorta-ruby v0.0.8; donated: #{member.donations_count} times; highest: #{member.highest_donation}, subscribed: #{is_member_subscribed}" 
                fd_requester_update_response = HTTParty.put("https://#{ENV["FRESHDESK_DOMAIN"]}.freshdesk.com/api/v2/contacts/#{requester_id.to_i}", headers: { 'Content-Type' => 'application/json' }, basic_auth: auth, body: {description: member_description}.to_json)
                fd_requester_update_status = fd_requester_update_response.response["status"]
                puts "Requester description update failed! FreshDesk returned #{fd_requester_update_status}." unless fd_requester_update_status == 200

                # Assign the campaign names to the original ticket in Freshdesk and add the "aorta_processed" tag
                new_tags = campaign_names + ["aorta_processed"]
                fd_ticket_update_response = HTTParty.put("https://#{ENV["FRESHDESK_DOMAIN"]}.freshdesk.com/api/v2/tickets/#{ticket_id.to_i}", headers: { 'Content-Type' => 'application/json' }, basic_auth: auth, body: {tags: new_tags}.to_json)
                fd_ticket_update_status = fd_ticket_update_response.response["status"]
                puts "Ticket tag update failed! FreshDesk returned #{fd_ticket_update_status}." unless fd_ticket_update_status == 200

            else
                p "Ignoring."
                return
            end
        end
    end

end