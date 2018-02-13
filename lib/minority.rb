require "minority/engine"

module Minority
	def self.load_files
		[
			"app/workers/donation_from_action",
			"app/workers/aorta/main",
			"app/workers/aorta/check_ticket",
			"app/workers/bank_acct/bank_payment_import",
			"app/workers/controlshift_cache_categorizations",
			"app/workers/controlshift_categorize",
			"app/workers/controlshift_categorize_one",
			"app/services/gdpr"
		]
	end

	def self.motd
		if ENV['RACK_ENV'] == 'development'
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
end
