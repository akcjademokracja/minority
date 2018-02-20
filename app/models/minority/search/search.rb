module Minority
	module Search
		extend ActiveSupport::Concern

		included do
			def include_rules
				if rules.is_a?(Hash)
					rules['include']
				else
					{"condition"=>"AND", "rules"=>[{"id"=>"subscribed", "field"=>"subscribed", "type"=>"string", "operator"=>"equal", "value"=>"on"}]}
				end
			end

			def exclude_rules
				if rules.is_a?(Hash)
					rules['exclude']
				else
					{"condition"=>"OR", "rules"=>[{"id"=>"noone", "field"=>"noone", "type"=>"string", "operator"=>"equal", "value"=>"on"}]}
				end
			end
		end

	end
end

Search.include Minority::Search