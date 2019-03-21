module Minority
  module MailingDataVocative
  	extend ActiveSupport::Concern

  	included do
  		def vocative
    		FirstName.where("first_name ILIKE ?", @member.first_name).first.try(:vocative) || @member.first_name
  		end
  	end
  end
end

# add the functions above to main MailingData model
