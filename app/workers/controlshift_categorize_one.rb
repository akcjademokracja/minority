class ControlshiftCategorizeOneWorker
  include Sidekiq::Worker
  
  def perform(row)
    @row = row

    issue_id = Rails.cache.fetch("CSL:category:issue:#{row["category_id"]}")
    Rails.logger.info("issue id mapping: CSL:category:issue:#{row["category_id"]} = #{issue_id}")
    return try_later if issue_id.nil?
    return if issue_id < 0 # the category has no mapping in issues here.

    issue = Issue.find issue_id
    Rails.logger.info("issue #{issue}")
    return if issue.nil?

    action = Action.includes(:campaign).where(
      technical_type: 'cby_petition',
      external_id: row["petition_id"]).first
    Rails.logger.info("action #{action}")
    return try_later if action.nil?

    action.campaign.issue = issue
    action.campaign.save!
  end

  def try_later
    ControlshiftCategorizeOneWorker.perform_in(1.minutes, @row)
  end
end
