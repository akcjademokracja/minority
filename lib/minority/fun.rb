
module Minority::Fun
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
