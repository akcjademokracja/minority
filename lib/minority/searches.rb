module Minority
  module Searches
    extend ActiveSupport::Concern

    INSERT_BEFORE = {
      'three-month-active' =>
      {
        optgroup: 'Actions',
        id: 'circle-engaged',
        label: 'Is in the Engaged circle of engagement (>=3 actions in last Q)',
        operators: ['equal', 'not_equal'],
        type: 'string',
        input: 'none',
        values: [1],
        sql: %Q{SELECT member_id
                FROM
                (
                  SELECT ma.member_id
                    FROM member_actions ma
                    JOIN actions a
                      ON a.id = ma.action_id
                    WHERE ma.created_at > getdate() - INTERVAL '90 DAY'
                    GROUP BY ma.member_id HAVING COUNT(*) >= 3
                  UNION
                  SELECT d.member_id
                  FROM donations d
                  WHERE d.created_at > getdate() - INTERVAL '90 DAY'

                  GROUP BY d.member_id HAVING COUNT(*) >= 2
                ) as t}
      }
    }

    included do
      class << self
        alias :filters_orig :filters
      end

      def self.filters
        f = filters_orig
        INSERT_BEFORE.each do |before_id, search_def| 
          idx = f.find_index { |search| search[:id] == before_id }
          unless idx.nil?
            f.insert idx, search_def
          end
        end
        f
      end
    end
  end
end

Search.include Minority::Searches
