module Minority
  module CtrlshiftWebhookCategorize
    extend ActiveSupport::Concern

    included do
      after_commit :categorize_csl

      def categorize_csl
        if job_type == 'data.full_table_exported' and table == 'categories'
          ControlshiftCacheCategorizationsWorker.perform_async url
        elsif table == 'categorized_petitions'
          ControlshiftCategorizeWorker.perform_async url
        end
      end
    end
  end
end

