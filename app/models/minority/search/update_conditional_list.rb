module Minority
  module Search
    module UpdateConditionalList
      extend ActiveSupport::Concern

      included do
  	    def update_conditional_list(list_name)
  		    conditional = ConditionalList.find_or_create_by(name: list_name)

  		    ActiveRecord::Base.transaction do
  			    conditional.conditional_list_members.delete_all
      	    result = RedshiftDB.connection.execute(sql)
      	    total_count = result.count

      	    result.each_slice(10_000) do |slice|
        	    values = slice.map { |row| "(#{row['id']}, #{conditional.id}, NOW(), NOW())" }
        	    ActiveRecord::Base.connection.execute(%Q{
					INSERT INTO conditional_list_members (member_id, conditional_list_id, created_at, updated_at)
					VALUES #{values.join(',')}
				})
            end
          end
        end
  	  end
    end
  end
end

