Tempora38::App.controllers :'bank_acct' do

    before do
        admin_required!
    end

    get '/import' do
      template = open(File.expand_path("../../../views/bank_acct/import.erb", __FILE__))
      view = ERB.new(template.read())
      view.result()
    end

    post '/import' do

        identity = IdentityLookup.new

        if params[:file] && params[:file][:type] == "text/csv"
            input_csv = params[:file][:tempfile]
        else
            {error: "No file or file is not CSV"}.to_json
        end

        CSV.foreach(input_csv, headers: true).each do |donation|
            # email,bank_acct_no,name,address,date,amount,transaction_id,topic
            # locate the donator by their email in Identity

            if donation["email"]
                if Member.exists?(email: donation["email"])
                    donator = identity.locate_by_email(donation, donation["email"])
                else
                    # locate a person by their account number
                    donator = identity.locate_by_bank_acct_no(donation, donation["bank_acct_no"])

                    # still no dice? attempt to locate by name
                    unless donator
                        identity.locate_by_name(donation, donation["name"], donation["address"]) unless donation["name"].nil?
                    end
                end
            else
                # locate a person by their account number
                donator = identity.locate_by_bank_acct_no(donation, donation["bank_acct_no"])

                unless donator
                    donator = identity.locate_by_name(donation, donation["name"], donation["address"])
                end
            end

            # by that point, the donator should be known
            p donator
            if donator
                # create donations
                new_donation = Donation.new({
                        amount: donation["amount"].to_f,
                        member: donator, 
                        external_id: donation["transaction_id"].to_s,
                        external_source: "konto",
                        created_at: DateTime.parse(donation["date"])
                        })

                # don't create duplicate donations
                if Donation.find_by(external_id: new_donation.external_id)
                    Padrino.logger.info("Ignoring duplicate donation #{new_donation.external_id}")
                    identity.csv_result << donation.to_h.values + ["ignoring duplicate donation #{new_donation.external_id}"]
                else
                    new_donation.save!
                end
            else
                puts "Donator not found."
                identity.csv_result << donation.to_h.values + ["the donator hasn't been found!"]
            end
        end

        content_type 'application/csv'
        attachment 'donations_output.csv'

        CSV.generate do |csv|
            csv << ["email", "bank_acct_no", "name", "address", "date", "amount", "transaction_id", "topic", "status"]
            identity.csv_result.each do |ary|
                csv << ary
            end
        end
    end
end


class IdentityLookup

    attr_accessor :csv_result

    def initialize
        @csv_result = []
    end

    def locate_by_bank_acct_no(donation, bank_acct_no)
        # a single person can have several accounts in Identity; we'll assign the donation to their most recent one
        puts "Locating member #{donation["name"]} by bank_acct: #{bank_acct_no}"
        donator = Member.where("external_ids ->> '#{bank_acct_no}' = '9999'").order(updated_at: :desc).first
        @csv_result << donation.to_h.values + ["success (bank_acct_no)"] if donator
        return donator
    end

    def locate_by_name(donation, name, address)
        # we have to resort to finding the donator by their names
        puts "Locating member #{donation["name"]} by name"
        return if name.nil?
        name = name.split(" ")
        fname = name[0]
        lname = name[-1]

        # there can be a couple of people by the same name
        people = Member.where(first_name: fname.strip.downcase.capitalize, last_name: fname.strip.downcase.capitalize)
        puts "Found #{people.count} people by that name."

        if people.count != 0
            if people.count == 1
                # if there's just one person by that name...
                puts "Just one person by that name."
                @csv_result << donation.to_h.values + ["success (exact name)"] 
                return people.first
            else
                # differentiate by postcodes
                # extract postcode
                postcode = address.scan(/[0-9]{2}-[0-9]{3}/).first
                puts "The postcode is #{postcode}."

                if postcode
                    more_people = people.joins(:addresses).where(addresses: {postcode: postcode})

                    if more_people.count != 0
                        # the donator may be the last person to perform a member action
                        donator = more_people.joins(:member_actions).order(updated_at: :desc).first
                        puts "Guessing that the member is #{donator.first_name} #{donator.last_name}, #{donator.email} out of #{people.count} people"
                        @csv_result << donation.to_h.values + ["guess (name and address)"]
                        return donator
                    else
                        puts "Can't guess the donator."
                        @csv_result << donation.to_h.values + ["can't guess the donator"]
                    end
                else
                    puts "No postcode to work with."
                end
            end
        else
            puts "No people found for name #{donation["name"]}"
        end
           
    end 

    def locate_by_email(donation, email)
        puts "Located #{donation["name"]} by email: #{email}"
        donator = Member.find_by(email: email)

        # if they don't have an external ID with a bank account number, add that
        unless donator.external_ids.has_key? "bank_acct_no"
            donator.external_ids["bank_acct_no"] = donation["bank_acct_no"].to_s
            donator.save!
        end

        @csv_result << donation.to_h.values + ["success (email)"]
        return donator
    end
end