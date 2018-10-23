require 'unicode'

class IdentityLookup
  attr_accessor :csv_result

  def initialize
    @csv_result = []
  end

  def locate(donation)
    expand_fnames = lambda {|fn| fn.prepend("locate_by_")}

    ["bank_acct_no", "name", "email"].map(&expand_fnames).dup do |m|
      donator = self.call(m, donation)
      return donator if donator
    end
  end

  private

  def unicode_normalize(name)
    name = name.strip
    name = Unicode::downcase(name)
    name = Unicode::capitalize(name)
  end

  def locate_by_bank_acct_no(donation)
    bank_acct_no = donation["bank_acct_no"]
    return nil unless bank_acct_no

    puts "Locating member #{donation["name"]} by bank_acct: #{bank_acct_no}"

    # a single person can have several accounts in Identity; we'll assign the donation to their most recent one

    donator = Member
                  .joins(:member_external_ids)
                  .where(member_external_ids: {
                                                system: 'bank_acct_no', 
                                                external_id: bank_acct_no
                                              })
                  .order(updated_at: :desc)
                  .first

    @csv_result << donation.to_h.values + ["success (bank_acct_no)"] if donator
    donator
  end

  def locate_by_name(donation)
    # we may have to resort to finding the donator by their names
    name = donation["name"]
    return nil unless name

    # now split the full name to first name and last name
    name = name.split(" ")
    fname = unicode_normalize(name[0])
    lname = unicode_normalize(name[-1])

    puts "Locating member #{donation["name"]} by name"

    people = Member.where(first_name: fname, last_name: lname)

    if people
      puts "Found #{people.count} people by that name."
    else
      # the name can be in reverse order, so if there are no people by that name we'll switch the order
      puts "No people found for name #{fname} #{lname}. Switching name order."
      people = Member.where(first_name: lname, last_name: fname)

      # check again
      unless people
        puts "No people found for name #{lname} #{fname}."
        return nil
      end

      puts "#{people.count} found for name #{lname} #{fname}."
    end

    if people.count > 1
      address = donation["address"]

      unless address
        puts "No address to work with, can't differentiate."
        return nil
      end

      postcode = address.scan(/[0-9]{2}-[0-9]{3}/).first
      puts "The postcode is #{postcode}."

      if postcode
        people = people.joins(:addresses).where(addresses: { postcode: postcode })

        if people
          # the donator we're looking for may be the last person to perform a member action
          donator = people.joins(:member_actions).order(updated_at: :desc).first
          puts "Guessing that the member is #{donator.first_name} #{donator.last_name}, #{donator.email} out of #{people.count} people"
          @csv_result << donation.to_h.values + ["success (guessing by name and postcode)"]
          return donator
        else
          puts "Can't guess the donator."
          return nil
        end
      else
        puts "The address didn't contain a postcode; can't differentiate."
        return nil
      end
    else
      puts "Just one person by that name. Exact match."
      @csv_result << donation.to_h.values + ["success (exact match)"]
      return people.first
    end
  end

  def locate_by_email(donation)
    email = donation["email"]
    return nil unless email

    if Member.exists?(email: email)
      # Great!
      puts "Located #{donation["name"]} by email: #{email}"
      donator = Member.find_by(email: email)

      # if they don't have an external ID with a bank account number, add that
      bank_acct_no = donation["bank_acct_no"].to_s
      unless donator.member_external_ids.where(system: "bank_acct_no", external_id: bank_acct_no)
        MemberExternalId.create!(
          member: donator,
          system: "bank_acct_no",
          external_id: bank_acct_no
        )
      end

      donator.reload
      @csv_result << donation.to_h.values + ["success (email)"]
      return donator
    else
      puts "Can't locate #{donation["name"]} by email."
      return nil
    end
  end

end
