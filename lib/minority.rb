require "minority/engine"

module Minority
	def self.load_files
		Dir.chdir(File.join(File.dirname(__FILE__), '..')) { Dir['app/workers/**/*.rb'] + Dir['app/services/**/*.rb'] }
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
