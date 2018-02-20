# This model doesn't exist in the main app
module Minority
  class FirstName < ApplicationRecord
  	self.table_name = "first_names"
  end
end
