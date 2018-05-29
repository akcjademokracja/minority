require "minority/engine"

module Minority
	def self.load_files
		Dir.chdir(File.join(File.dirname(__FILE__), '..')) do 
      %w[workers services models].map do |d| 
        Dir["app/#{d}/**/*.rb"]
      end.reduce :+
    end
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
        puts
        puts "Minority rev." + " " + `git rev-parse --short HEAD`.strip
	end
end
