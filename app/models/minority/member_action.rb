module Minority
  module MemberAction
    extend ActiveSupport::Concern
    included do
      after_commit :create_donate
      def create_donate
        DonationFromActionWorker.perform_async(id) if self.action.action_type == 'donate'
      end
    end
  end
end

MemberAction.include Minority::MemberAction
