# coding: utf-8
require 'httparty'

class AortaCheckTicketWorker
    include Sidekiq::Worker
    # If the worker doesn't complete their work in 4 minutes, because it is for example rate-limited...
    # ...let the lock expire, since we *can* have duplicate workers with the same payload/ticket_id
    sidekiq_options unique: :until_executing, log_duplicate_payload: true, lock_timeout: 4

    def perform(ticket_id)

        @ticket_id = ticket_id.to_i
        auth = {username: ENV['FRESHDESK_API_TOKEN'], password: "X"}
        
        result = fd_get_ticket(auth)

        # If the subject is empty, stop processing the ticket; FreshDesk will throw 400 Bad Request at you if you try updating a ticket without a subject.
        # Thanks FreshDesk!
        return if result[:subject].empty?

        # Do not process non-email tickets
        return if result[:source].to_i != 1

        # Do not process if the ticket e-mail wasn't sent to the "contact" e-mail address
        return unless result[:to_emails].include? ENV["CONTACT_EMAIL"]

        # First, check who we're dealing with, even before opt-out/forget operations
        member = Member.find_by(email: result[:email])

        new_tags = []

        puts "#{@ticket_id}: The ticket's type is #{result[:type]}."

        unless result[:type] == "Do wypisania" or result[:type] == "Wypisany" or result[:type] == "Do usunięcia danych" or result[:type] == "Mało kasy" or result[:type] == "Mniej maili"
            # If the ticket isn't an opt-out mailing, check if it's been processed already

            unless result[:tags].include? "aorta_processed"

                puts "#{@ticket_id}: Ticket not processed yet."

                # Assign campaign names to tags if the ticket is a reply to some mailing
                unless result[:subject].scan(/^(odp|sv|re): (.+)/i).empty?
                    puts "It's a reply, checking campaign names."
                    result[:subject].gsub!(/^(odp|sv|re): /i, '')

                    # Now we have to get mailings with that subject and extract campaign names from them
                    # Then, we assign these campaign names to FreshDesk tickets as tags

                    # Add campaign names to new_tags
                    new_tags = new_tags + identity_get_mailing_info(result[:subject])  
                else
                    puts "It's not a reply. Proceeding to watchdog operation."
                end

            else

                if result[:tags].include? "aorta_reprocess"
                    puts "#{@ticket_id}: Ticket marked for reprocessing."
                    unless result[:subject].scan(/^(odp|sv|re): (.+)/i).empty?
                        puts "It's a reply, checking campaign names."
                        result[:subject].gsub!(/^(odp|sv|re): /i, '')
                        new_tags = new_tags + identity_get_mailing_info(result[:subject])  
                    else
                        puts "It's not a reply. Proceeding to watchdog operation."
                    end
                else
                    puts "#{@ticket_id}: entry processed, skipping."
                    return
                end

            end

        else
            # Opt-out/forget operations, adding to custom lists etc.

            case result[:type]
            when "Do usunięcia danych"
                print "Forgetting member... "
                Member::GDPR.optout(member, "Aorta opt-out") if member
                # Not implemented yet
                #Member::GDPR.forget(member, reason) if member
                new_tags << "zapomniano"
                puts "forgotten"
            when "Do wypisania"
                print "Unsubscribing member... "
                Member::GDPR.optout(member, "Aorta opt-out") if member
                new_tags << "wypisano"
                puts "unsubscribed"
            when "Mało kasy"
                print "Adding member to non-donation-asking group... "
                low_money_list = List.find_by(name: "mało kasy")
                low_money_list << member
                new_tags << "dodano_do_malo_kasy"
                puts "done"
            when "Mniej maili"
                print "Adding member to lower mailing count list..."
                low_mailing_list = List.find_by(name: "mniej maili")
                low_mailing_list << member
                new_tags << "dodano_do_mniej_maili"
                puts "done"
            when "Wypisany"
                # Aorta probably got this ticket, because FreshDesk executed some Supervisor rule, which updated the ticket again
                puts "Member already unsubscribed."
                return
            end

            # Assign campaign names to tags if the ticket is a reply to some mailing
            unless result[:subject].scan(/^(odp|sv|re): (.+)/i).empty?
                puts "It's a reply, checking campaign names."
                result[:subject].gsub!(/^(odp|sv|re): /i, '')

                # Now we have to get mailings with that subject and extract campaign names from them
                # Then, we assign these campaign names to FreshDesk tickets as tags

                # Add campaign names to new_tags
                new_tags = new_tags + identity_get_mailing_info(result[:subject])  
            else
                puts "It's not a reply. Proceeding to watchdog operation."
            end

        end

        
        # Now that we have campaign names, time to get watchdog data and send it to FreshDesk
        # If someone's "unsubscribed_at" is nil it probably means they're subscribed
        # Example unsubbed member: 523713
        # Get all unsubs with: MemberSubscription.where("member_subscriptions.unsubscribed_at IS NOT ?", nil).to_a
        if member
            is_member_subscribed = !MemberSubscription.where(member_id: member.id).first.unsubscribed_at
            member_description = "Donated: #{member.donations_count || 0} times; highest: #{member.highest_donation || 0}, subscribed: #{is_member_subscribed}."
            fd_update_requester_info(auth, result[:requester_id], member_description)
        else
            member_description = "No person by that email in Identity."
            # Save 1 API call by not sending that to FreshDesk
            fd_update_requester_info(auth, result[:requester_id], member_description)
        end
            
        # Update the ticket's tags at the end
        # If the source is not an e-mail, you get errors upon trying to update the ticket. 
        # Thanks FreshDesk!
        new_tags << "aorta_processed"
        fd_update_ticket_tags(auth, new_tags) unless result[:source].to_i != 1
              
    end

    private

    def fd_get_ticket(auth)
        # Cost: 2 FreshDesk API credits
        response = HTTParty.get("https://#{ENV["FRESHDESK_DOMAIN"]}.freshdesk.com/api/v2/tickets/#{@ticket_id}?include=requester", basic_auth: auth)
        fd_rate_limit_check(response)
        result = {email: response["requester"]["email"], requester_id: response["requester_id"], subject: response["subject"], type: response["type"], tags: response["tags"], source: response["source"], to_emails: response["to_emails"]}
        return result
    end

    def fd_rate_limit_check(response)
        # Throw an exception upon hitting the rate limit
        if response.response["x-ratelimit-remaining"].to_i < 2 or response.response["status"] == "429"
          # reschedule it for later
          puts "Rate limit hit. Will retry after #{(response.response["retry-after"].to_i + 10) / 60} minutes."
          AortaCheckTicketWorker.perform_in(response.response["retry-after"].to_i + 10, @ticket_id)
          return
        elsif response.response["status"] != "200 OK"
            raise AortaCheckTicketWorker::FreshDeskError.new("Something went wrong! Status: #{response.response["status"]}")
        end
    end

    def fd_update_requester_info(auth, requester_id, new_requester_description)
        # Cost: 1 FreshDesk API credit
        response = HTTParty.put("https://#{ENV["FRESHDESK_DOMAIN"]}.freshdesk.com/api/v2/contacts/#{requester_id.to_i}", headers: { 'Content-Type' => 'application/json' }, basic_auth: auth, body: {description: new_requester_description}.to_json)
        fd_rate_limit_check(response)
        return response.response["status"]
    end

    def fd_update_ticket_tags(auth, new_tags)

        # If an opt-out operation was carried out, change the type accordingly
        unless new_tags.include? "wypisano"
            request_body = {tags: new_tags}.to_json
        else
            request_body = {tags: new_tags, type: "Wypisany", status: 4}.to_json
        end

        # Cost: 1 FreshDesk API credit
        response = HTTParty.put("https://#{ENV["FRESHDESK_DOMAIN"]}.freshdesk.com/api/v2/tickets/#{@ticket_id}", headers: { 'Content-Type' => 'application/json' }, basic_auth: auth, body: request_body)
        fd_rate_limit_check(response)
    end

    def identity_get_mailing_info(subject)

        # BY_TAGS

        # An array of IDs matching the criteria, ex. [101, 102] or an empty array if nothing found
        mailing_ids = Mailing.joins(:test_cases).
                            where("mailing_test_cases.template LIKE ?", "%#{subject}%").
                            select('DISTINCT mailings.id').pluck(:id)

        unless mailing_ids.empty?
            # This is an array of Mailing objects or an array containing a single Mailing object
            mailings_by_tags = Mailing.where(id: mailing_ids)
            mailings_by_tags_campaigns = mailings_by_tags.map {|mailing| mailing.name.split("-")[0].truncate(20, omission: '...')}
        else
            mailings_by_tags_campaigns = []
        end

        # BY_SUBJECT

        # An array of Mailing objects or an array containing a single Mailing object
        mailings_by_subject = Mailing.where(subject: subject)

        unless mailings_by_subject.empty?
            mailings_by_subject_campaigns = mailings_by_subject.map {|mailing| mailing.name.split("-")[0].truncate(20, omission: '...')}
        else
            mailings_by_subject_campaigns = []
        end

        # FINAL OPERATION

        return (mailings_by_tags_campaigns + mailings_by_subject_campaigns).uniq

    end

    class FreshDeskRateLimitHit < StandardError
        def initialize(retry_after)
            retry_after = retry_after.to_i
            super("FreshDesk rate limit hit! New API credits available in #{retry_after/60} minutes.")
        end
    end  

    class FreshDeskError < StandardError
        def initialize(message)
            super(message)
        end
    end

end
