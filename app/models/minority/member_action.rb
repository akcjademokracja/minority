module Minority
  module MemberAction
    extend ActiveSupport::Concern
    included do
      after_commit :create_donate
      def create_donate
        DonationFromActionWorker.perform_async(id) if ['donate', 'regular_donate'].include? self.action.action_type 
      end
    end
  end
end

