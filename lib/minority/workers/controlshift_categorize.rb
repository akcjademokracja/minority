class ControlshiftCategorizeWorker
  include Sidekiq::Worker
  
  def perform(url)
    table = open(url, 'r:utf-8')
    csv = SmarterCSV.process(table, chunk_size: 25) do |lines|
      lines.each do |row|
        ControlshiftCategorizeOneWorker.perform_async(row)
      end
    end
  end
end
