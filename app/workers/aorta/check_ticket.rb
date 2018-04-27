# coding: utf-8
require 'httparty'
require 'babosa'

class AortaCheckTicketWorker
    include Sidekiq::Worker
    # If the worker doesn't complete their work in 4 minutes, because it is for example rate-limited...
    # ...let the lock expire, since we *can* have duplicate workers with the same payload/ticket_id
    sidekiq_options unique: :until_executing, log_duplicate_payload: true, lock_timeout: 4

    def perform(ticket_id)

        @ticket_id = ticket_id.to_i
        auth = {username: ENV['FRESHDESK_API_TOKEN'], password: "X"}

        result = fd_get_ticket(auth)
        return if result.nil?

        # If the subject is empty, stop processing the ticket; FreshDesk will throw 400 Bad Request at you if you try updating a ticket without a subject.
        # Thanks FreshDesk!
        return if result[:subject].empty?

        # Do not process non-email tickets
        return if result[:source].to_i != 1

        # Do not process if the ticket e-mail wasn't sent to the "contact" e-mail address
        if result[:to_emails]
          return unless result[:to_emails].include? ENV["CONTACT_EMAIL"]
        else
          # Apparently you can create tickets on Freshdesk itself and they don't have the "to_emails" field.
          # We don't want to process these.
          return
        end
        
        # First, check who we're dealing with, even before opt-out/forget operations
        member = Member.find_by(email: result[:email])

        # googlemail.com -> gmail.com fix
        if !member and result[:email].include? "@googlemail.com"
          result[:email].gsub!("@googlemail.com", "@gmail.com")
          member = Member.find_by(email: result[:email])
        end
        
        # Declare this in advance; this may get changed later
        is_regular_donator = false

        new_tags = []

        puts "#{@ticket_id}: The ticket's type is #{result[:type]}."

        case result[:type]
        when "Do usunięcia danych"
          print "Forgetting member... "
          Member::GDPR.optout(member, "Aorta opt-out") if member
          # Not implemented yet
          #Member::GDPR.forget(member, reason) if member
          new_tags << "zapomniano"
          puts "forgotten"
        when "Do wypisania"
          if member
            print "Unsubscribing member... "
            Member::GDPR.optout(member, "Aorta opt-out")
            puts "unsubscribed"
            new_tags << "wypisano"
          else
            # Can't unsubscribe members who aren't members, that's quite obvious.

            # There's a workaround, though. We'll scan the incoming e-mail body
            # for the actual e-mail address the person was trying to unsubscribe

            # Some people try to unsubscribe their e-mail address "A" by writing from
            # their "B" e-mail address. Happens way too often

            puts "MEMBER TO UNSUBSCRIBE NOT FOUND IN THE DATABASE. Trying a workaround..."

            unsub_email_regex = /https:\/\/baza.akcjademokracja.pl\/subscriptions\/unsubscribe\?email=(.+?)&/
            email_to_unsub = result[:description].match(unsub_email_regex)[1]

            email_to_unsub.gsub!("%40", "@") if email_to_unsub.include?("%40")

            member_to_unsub = Member.find_by(email: email_to_unsub)

            if member_to_unsub
              Member::GDPR.optout(member_to_unsub, "Aorta opt-out, workaround mode")
              new_tags << "wypisano"
            else
              puts "CANNOT UNSUBSCRIBE THE MEMBER! MEMBER NOT FOUND IN THE DATABASE."
              new_tags << "nie_wypisano"

              # notify of this fact by email

              ticket_link = '<a href="' + "/helpdesk/tickets/#{@ticket_id}" + '">tutaj</a>'

              TransactionalMail.send_email(
                to: ["aorta@akcjademokracja.freshdesk.com"],
                from: "Aorta | Akcja Demokracja <#{Settings.options.default_mailing_from_email}>",
                subject: "[ERROR] Freshdesk: #{@ticket_id}, błąd wypisywania",
                body: "Cześć,
                <br></br>
                Nastąpił błąd wypisywania osoby z listy mailingowej; danej osoby nie ma w bazie.
                <br></br>
                Sprawa do zbadania #{ticket_link}.
                <br></br>
                Pozdrowienia,
                <br></br>
                Automatyczny Organizator Regularnej Transakcji Aktywistycznej"
              )
            end

          end
        when "Mało pieniędzy", "Mniej maili", "Dodanie do listy regularnie wpłacających"
          lists = {
            "Mało pieniędzy": "mało pieniędzy",
            "Mniej maili": "mniej maili",
            "Dodanie do listy regularnie wpłacających": "Wpłacają Regularnie"
          }

          tgt_list = lists[result[:type].to_sym]
          tgt_list_tag = tgt_list.to_slug.transliterate.downcase.to_s.gsub(" ", "_")

          if member
            new_tags << "dodano_do_#{tgt_list_tag}" if add_member_to_list(member, tgt_list)
          else
            # In reality this shouldn't be happening.
            # I can only think of the situation where the user mistags some ticket
            # or maybe the inquirer pays by wire transfer and messages from another, non-member e-mail addr.
            puts "The person isn't a member, somehow. Not adding to list #{tgt_list}."
            return
          end
        when "Zamiana imienia i nazwiska"
          puts "Fix first name & last name order..."
          if result[:tags].include? "naprawiono_imie_nazwisko"
            puts "They already had their name order fixed... ignoring."
            return
          end
          puts "Current data: #{member.first_name} #{member.last_name}"
          puts "Changing to: #{member.last_name} #{member.first_name}"
          new_lname = member.first_name
          new_fname = member.last_name
          member.update!(first_name: new_fname, last_name: new_lname)
          new_tags << "naprawiono_imie_nazwisko" 
        when "Wypisany"
          # Aorta probably got this ticket, because FreshDesk executed some Supervisor rule, which updated the ticket again
          puts "Member already unsubscribed."
          # EXIT
          return
        else
          if result[:tags].include? "aorta_processed"
            puts "#{@ticket_id}: entry processed and not marked for reprocessing"
            # EXIT
            return
          end
        end
        new_tags += campaign_tags(result)

        email_subscription = Subscription.find_by name: 'email'

        # Now that we have campaign names, time to get watchdog data and send it to FreshDesk
        # If someone's "unsubscribed_at" is nil it probably means they're subscribed
        # Example unsubbed member: 523713
        # Get all unsubs with: MemberSubscription.where("member_subscriptions.unsubscribed_at IS NOT ?", nil).to_a
        if member
          member_subscription = MemberSubscription.where(member_id: member.id, subscription_id: email_subscription.id).first
          is_member_subscribed = !member_subscription.nil? and member_subscription.unsubscribed_at.nil?
          first_action = member.actions.any? ? member.actions.first.name.to_slug.transliterate.to_s : "none"
          top_issue = member.issues.any? ? member.issues.group(:name).count.sort_by{|k, v| v}.reverse.to_h.first.join(", ") : "none"
          is_regular_donator = member.has_regular_donation?
          member_description = "Donated: #{member.donations_count || 0} times; 
          highest: #{member.highest_donation || 0}, 
          subscribed: #{is_member_subscribed}. 
          First action: #{first_action},
          top issue: #{top_issue}"
          fd_update_requester_info(auth, result[:requester_id], member_description)
        else
          member_description = "No person by that email in Identity."
          # Save 1 API call by not sending that to FreshDesk
          fd_update_requester_info(auth, result[:requester_id], member_description)
        end

        # Custom filters
        money_keywords = [
          "numer konta", "wpłat", "zleceni", "przelew", "nr konta", "numer konta", "numeru konta",
          "darowizny", "płatności", "finansowe", "płatność", "płatność", "darowizna", "finansowanie",
          "darowizn"
        ]

        new_tags << "pieniądze" if custom_filter(result, money_keywords)

        # Update the ticket's tags at the end
        # If the source is not an e-mail, you get errors upon trying to update the ticket. 
        # Thanks FreshDesk!
        new_tags << "aorta_processed"
        fd_update_ticket_tags(auth, new_tags, is_regular_donator) unless result[:source].to_i != 1
    end

    private

    def campaign_tags(result)
      unless result[:subject].scan(/^(odp|sv|re): (.+)/i).empty?
        result[:subject].gsub!(/^(odp|sv|re): /i, '')
        return identity_get_mailing_info(result[:subject])  
      else
        return []
      end
    end

    def fd_get_ticket(auth)
        # Cost: 2 FreshDesk API credits
        response = HTTParty.get("https://#{ENV["FRESHDESK_DOMAIN"]}.freshdesk.com/api/v2/tickets/#{@ticket_id}?include=requester", basic_auth: auth)
        return nil if rate_limit_hit? response
        result = {
          email: response["requester"]["email"],
          requester_id: response["requester_id"],
          subject: response["subject"],
          type: response["type"],
          tags: response["tags"],
          source: response["source"],
          to_emails: response["to_emails"],
          description: response["description"],
          description_text: response["description_text"]
        }
        return result
    end

    def rate_limit_hit?(response)
        # Throw an exception upon hitting the rate limit
        if response.headers["x-ratelimit-remaining"].to_i < 2 or response.response["status"] == "429"
          # reschedule it for later
          puts "Rate limit hit. Will retry after #{(response.response["retry-after"].to_i + 10) / 60} minutes."
          AortaCheckTicketWorker.perform_in(response.headers["retry-after"].to_i + 10, @ticket_id)
          return true
        elsif response.response["status"] != "200 OK"
          raise AortaCheckTicketWorker::FreshDeskError.new("Something went wrong! Status: #{response.response["status"]} ReqId: #{response.headers['x-requestid']}")
        end
        false
    end

    def fd_update_requester_info(auth, requester_id, new_requester_description)
        # Cost: 1 FreshDesk API credit
        response = HTTParty.put("https://#{ENV["FRESHDESK_DOMAIN"]}.freshdesk.com/api/v2/contacts/#{requester_id.to_i}", headers: { 'Content-Type' => 'application/json' }, basic_auth: auth, body: {description: new_requester_description}.to_json)
        return nil if rate_limit_hit? response
        return response.response["status"]
    end

    def fd_update_ticket_tags(auth, new_tags, is_regular_donator)

        request_body = {}

        # If an opt-out operation was carried out, change the type and status accordingly
        if new_tags.include? "wypisano"
          request_body[:type] = "Wypisany"
          request_body[:status] = 4
        end

        # If the member's a regular donator, assign a higher priority to the ticket
        if is_regular_donator
          request_body[:priority] = 3
        end

        # Finally, add the tags
        request_body[:tags] = new_tags

        # Cost: 1 FreshDesk API credit
        response = HTTParty.put("https://#{ENV["FRESHDESK_DOMAIN"]}.freshdesk.com/api/v2/tickets/#{@ticket_id}", headers: { 'Content-Type' => 'application/json' }, basic_auth: auth, body: request_body.to_json)
        return false if rate_limit_hit? response
        return true
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
            mailings_by_tags_campaigns = mailings_by_tags.map {|mailing| mailing.name.split("-")[0].truncate(20, omission: "")}
        else
            mailings_by_tags_campaigns = []
        end

        # BY_SUBJECT

        # An array of Mailing objects or an array containing a single Mailing object
        mailings_by_subject = Mailing.where(subject: subject)

        unless mailings_by_subject.empty?
            mailings_by_subject_campaigns = mailings_by_subject.map {|mailing| mailing.name.split("-")[0].truncate(20, omission: "")}
        else
            mailings_by_subject_campaigns = []
        end

        # FINAL OPERATION

        return (mailings_by_tags_campaigns + mailings_by_subject_campaigns).map{|tag| tag.to_slug.transliterate.to_s.downcase}.uniq

    end

    def add_member_to_list(member, list_name)
      print "Adding member to #{list_name} list..."
      tgt_list = List.find_or_create_by(name: list_name)
      unless tgt_list.members.include? member
        tgt_list.add_new_member(member)
      else
        print " they already belong to that list."
        return false
      end
      print " done."
      return true
    end

    def custom_filter(result, keywords)
      text = result[:description_text].split("kontakt@akcjademokracja.pl")[0]

      keywords.each do |kw|
        if text.include? kw
          return true
        end
      end

      return false
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
