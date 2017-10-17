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
        csv_placeholder = nil

        CSV.new(csv_placeholder, headers: true).each do |donation|
            # email,bank_acct_no,name,address,date,amount,payment_no,topic
            # locate the donator by their email in Identity

            donator = nil

            if donation["email"]
                if Member.exists?(email: donation["email"])
                    donator = Member.find_by(email: donation["email"])

                    # if they don't have an external ID with a bank account number, add that
                    unless donator.external_ids.has_key? "bank_acct_no"
                        donator.external_ids["bank_acct_no"] = donation["bank_acct_no"].to_s
                    end
                else
                    puts "No person by that email can be found in Identity, searching by account number..."
                    # locate a person by their account number
                    donator = locate_by_bank_acct_no(donation["bank_acct_no"])

                    # still no dice? attempt to locate by name
                    unless donator
                        locate_by_name(donation["name"])
                    end
                end
            else
                puts "No email specified; attempting to locate the donator by their account number..."

                # locate a person by their account number
                donator = locate_by_bank_acct_no(donation["bank_acct_no"])

                unless donator
                    donator = locate_by_name(donation["name"])
                end
            end

            # by that point, the donator should be known
            unless donator.nil?
                # create donations
            else
                puts "Donator not found. How is that possible?"
            end

        end

    end

    private

    def locate_by_bank_acct_no(bank_acct_no)
        return Member.where("external_ids ->> '#{bank_acct_no}' = '9999'").order(updated_at: :desc).first
    end

    def locate_by_name(name)
        is_suspected = false

        # we have to resort to finding the donator by their names
        fname, _, lname = name.split(" ")

        # there can be a couple of people by the same name
        people = Member.where(first_name: fname, last_name: lname)

        # extract postcode
        postcode = donation["address"].scan(/[0-9]{2}-[0-9]{3}/).first

        if people.count > 1
            # differentiate by postcodes
            people = people.joins(:addresses).where(addresses: {postcode: "02-123"})
            # the donator may be the last person to perform a member action
            donator = people.joins(:member_actions).order(updated_at: :desc).first
            # update suspected flag
            is_suspected = true
        end

        return {donator: donator, is_suspected: is_suspected}
    end
    
end
