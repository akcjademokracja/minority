class ControlshiftCacheCategorizationsWorker
  include Sidekiq::Worker

  def perform(url)
    table = open(url, 'r:utf-8')
    csv = SmarterCSV.process(table, chunk_size: 25) do |lines|
      lines.each do |row|
        issue = Issue.where("name ILIKE ?", row[:name]).first
        if issue.nil?
          Padrino.cache["CSL:category:issue:#{row[:id]}"] = -1
        else
          Padrino.cache["CSL:category:issue:#{row[:id]}"] = issue.id
        end
      end
    end
  end
end
