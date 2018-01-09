require './identity_lookup.rb'

class BankPaymentImportWorker
    include Sidekiq::Worker

    def perform(input_csv, password, email)
        identity = IdentityLookup.new

        CSV.foreach(input_csv, headers: true).each do |donation|
            
            # donator unknown
            donator = nil

            # locate the donator by their email in Identity if their email is given
            donator = identity.locate_by_email(donation, donation["email"]) if donation["email"]
            # locate a person by their account number
            donator = identity.locate_by_bank_acct_no(donation, donation["bank_acct_no"]) unless donator
            # still no dice? attempt to locate by name
            donator = identity.locate_by_name(donation, donation["name"], donation["address"]) unless donator or donation["name"].nil?

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
                if Donation.find_by(external_id: new_donation.external_id) or Donation.find_by(amount: donation["amount"].to_f, member: donator, created_at: DateTime.parse(donation["date"]))
                    Padrino.logger.info("Ignoring duplicate donation #{new_donation.external_id}")
                    identity.csv_result << Array.new(donation.to_h.values.count) + ["ignoring duplicate donation #{new_donation.external_id}"]
                else
                    identity.csv_result << Array.new(donation.to_h.values.count) + ["creating new donation #{new_donation.external_id}"]
                    new_donation.save!
                end
            else
                puts "Donator not found."
                identity.csv_result << donation.to_h.values + ["the donator hasn't been found!"]
            end
        end

        # send identity.csv_result here

        output = CSV.generate do |csv|
            csv << ["email", "bank_acct_no", "name", "address", "date", "amount", "transaction_id", "topic", "status"]
            identity.csv_result.each do |ary|
                csv << ary
            end
        end

        zip_filename = Time.now.utc.strftime("%Y-%m-%d %H_%M_%S")
        

        Zip::Archive.open(zip_filename, Zip::CREATE) do |ar|
            ar.add_buffer('donations_output.csv', output)
            ar.encrypt(password)
        end

        TransactionalMail.send_email(
            to: [email],
            subject: "Wynik importu wplat recznych dla #{name}",
            body: 'No elo,',
            from: "#{Settings.app.org_title} <#{Settings.options.default_mailing_from_email}>",
            source: 'identity:email-csv',
            files: [
                {
                    path: zip_filename,
                    filename: zip_filename
                }
            ]
        )

    end
end