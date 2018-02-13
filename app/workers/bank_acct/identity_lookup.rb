require 'unicode'

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
        fname = unicode_normalize(name[0])
        lname = unicode_normalize(name[-1])

        unless Member.where(first_name: fname, last_name: lname).count == 0
            people = Member.where(first_name: fname, last_name: lname)
            puts "Found #{people.count} people by that name."
        else
            # the name can be in reverse order, so if there are no people by that name we'll switch the order
            puts "No people found for name #{fname} #{lname}. Switching name order."
            people = Member.where(first_name: lname, last_name: fname)
            # give up if there still are no records
            if people.count == 0
                puts "No people found for name #{lname} #{fname}."
                return nil
            else
                puts "#{people.count} found for name #{lname} #{fname}."
            end
        end

        # there can be a couple of people by the same name, differentiate by postcodes
        if people.count > 1
            postcode = address.scan(/[0-9]{2}-[0-9]{3}/).first
            puts "The postcode is #{postcode}."

            if postcode
                people = people.joins(:addresses).where(addresses: {postcode: postcode})
                unless people.count == 0
                    # the donator may be the last person to perform a member action
                    donator = people.joins(:member_actions).order(updated_at: :desc).first
                    puts "Guessing that the member is #{donator.first_name} #{donator.last_name}, #{donator.email} out of #{people.count} people"
                    @csv_result << donation.to_h.values + ["success (guessing by name and postcode)"]
                    return donator
                else
                    puts "Can't guess the donator."
                    return nil
                end
            else
                puts "No postcode to work with, can't differentiate."
                return nil
            end
        else
            puts "Just one person by that name."
            @csv_result << donation.to_h.values + ["success (exact match)"]
            return people.first
        end
    end

    def locate_by_email(donation, email)

        if Member.exists?(email: email)
            puts "Located #{donation["name"]} by email: #{email}"
            donator = Member.find_by(email: email)

            # if they don't have an external ID with a bank account number, add that
            unless donator.external_ids.has_key? "bank_acct_no"
                donator.external_ids["bank_acct_no"] = donation["bank_acct_no"].to_s
                donator.save!
            end

            @csv_result << donation.to_h.values + ["success (email)"]
            return donator
        else
            puts "Can't locate #{donation["name"]} by email."
            return nil
        end
    end

    private

    def unicode_normalize(name)
        name = name.strip
        name = Unicode::downcase(name)
        name = Unicode::capitalize(name)
    end

end