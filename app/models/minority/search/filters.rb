module Minority
  module Search
    module Filters
      extend ActiveSupport::Concern

      CHANGE_LABEL = {
        'has-taken-issue' => 'Segments include',
        'has-taken-issue-category' => 'Pillars include'
      }

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
        },
        'has-taken-action-type' =>
        {
          optgroup: 'Actions',
          id: 'has-taken-csl-action',
          label: "Has taken any CSL action",
          operators: ['equal', 'not_equal'],
          type: 'string',
          input: 'none',
          sql: "SELECT member_id FROM member_actions ma JOIN actions a ON a.id = ma.action_id WHERE a.technical_type = 'cby_petition'",
        },
        'was-regular-donor' =>
        {
          optgroup: 'Donations',
          id: 'account-donor',
          label: 'Donated to account in last 2 months',
          operators: %w[equal not_equal],
          type: 'string',
          input: 'none',
          values: [1],
          sql: 'SELECT member_id FROM donations WHERE medium = \'konto\' and age(created_at) <= interval \'2 months\''
        },
      }

      included do
        class << self
          alias :filters_orig :filters
        end

        def self.filters
          f = filters_orig
          idx = 0
          while idx < f.length
            criterion = f[idx]
            if new_criterion = INSERT_BEFORE[criterion[:id]]
              f.insert idx, new_criterion
              idx += 1 # skip inserted one
            elsif new_label = CHANGE_LABEL[criterion[:id]]
              criterion[:label] = new_label
            end
            idx += 1
          end
          f
        end
      end
    end
  end
end

