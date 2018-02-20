class ControlshiftCategorizeOneWorker
  include Sidekiq::Worker
  
  def perform(row)
    @row = row

    begin
      issue_id = ControlshiftIssueLink.find(row["category_id"]).try(:issue_id)
      logger.info("issue id mapping: CSL:category:issue:#{row["category_id"]} = #{issue_id}")
      return if issue_id < 0 # the category has no mapping in issues here.

      issue = Issue.find issue_id
      logger.info("issue candidate #{issue.try(:name)}")
      return if issue.nil?

      action = Action.includes(:campaign).where(
        technical_type: 'cby_petition',
        external_id: row["petition_id"]).first
      logger.info("CSL petition action #{action.try(:name)}")
      return try_later if action.nil? or action.campaign.nil?

      action.campaign.issue = issue
      action.campaign.save!

    rescue ActiveRecord::RecordNotFound => e
      return try_later
    end
  end

  def try_later
    ControlshiftCategorizeOneWorker.perform_in(5.minutes, @row)
  end
end
