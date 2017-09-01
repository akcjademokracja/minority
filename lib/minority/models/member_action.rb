class MemberAction < ActiveRecord::Base
  after_commit :create_donate
  def create_donate
    if self.action.action_type == 'donate'
      DonationFromActionWorker.perform_async id
    end
  end
end
