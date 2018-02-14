module Minority
  class Engine < ::Rails::Engine
    isolate_namespace Minority
    initializer "minority", after: :load_config_initializers do |app|
    	Minority.motd
  		Minority.load_files.each do |file|
  			puts "Loading module: #{file.to_s} "
    		require_relative File.join("../..", file)
  		end
	end
  end
end


