class ControlshiftCacheCategorizationsWorker
  include Sidekiq::Worker

  def perform(url)
    table = open(url, 'r:utf-8')
    csv = SmarterCSV.process(table, chunk_size: 25) do |lines|
      lines.each do |row|
        issue = issue_for_category row[:name]
        if issue.nil?
          Rails.cache.write("CSL:category:issue:#{row[:id]}", -1)
        else
          Rails.cache.write("CSL:category:issue:#{row[:id]}", issue.id)
        end
      end

    def issue_for_category(name)
      if Settings.csl.category_map.has_key? name.downcase
        name = Settings.csl.category_map[name.downcase]
      end
      category = IssueCategory.where("name ILIKE ?", name).first
      category.nil? ? issue_name = name : issue_name = "#{name} - inne"
      return Issue.where("name ILIKE ?", issue_name).first
    end
    
    end
  end
end