module Minority
  module Search
    module Filters
      def self.filters
        [{
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
         },
         {
           optgroup: 'Actions',
           id: 'has-taken-csl-action',
           label: "Has taken any CSL action",
           operators: ['equal', 'not_equal'],
           type: 'string',
           input: 'none',
           sql: "SELECT member_id FROM member_actions ma JOIN actions a ON a.id = ma.action_id WHERE a.technical_type = 'cby_petition'",
         },
         {
           optgroup: 'Donations',
           id: 'account-donor',
           label: 'Donated to account in last 2 months',
           operators: %w[equal not_equal],
           type: 'string',
           input: 'none',
           values: [1],
           sql: 'SELECT member_id FROM donations WHERE medium = \'konto\' and age(created_at) <= interval \'2 months\''
         }]
      end
    end
  end
end

