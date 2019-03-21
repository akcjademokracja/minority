require 'minority/engine'

module Minority
  def self.load_files
    Dir.chdir(File.join(File.dirname(__FILE__), '..')) do
      %w[workers services models].map do |d|
        Dir["app/#{d}/**/*.rb"]
      end.flatten
    end
  end

  def self.init
    a = Minority::Search
    b = Search
    b.include a
    Search.include Minority::Search
    Search.include Minority::Search::Filters
    Search.include Minority::Search::UpdateConditionalList
    TextBlastData.include Minority::TextBlastData
    CtrlshiftWebhook.include Minority::CtrlshiftWebhookCategorize
    Mailer::MailingData.include Minority::MailingDataVocative
    # MemberAction.include Minority::MemberAction
  end

  def self.motd
    puts %q[
                         .-"""""-.
                        (('     `))
Loading Minority...    .'`-.....-'`.
                     /{\\  .--. oO ,\\
                     | { ><<_ @}'.%` |
                     | {/%,`--'  `&' |
                      \  `&'    `%' /
                       `..:%.:::.7.'
                         `"""""""'
				]
  end
end
