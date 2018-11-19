module Minority
  class Engine < ::Rails::Engine
    isolate_namespace Minority
    initializer "minority", after: :load_config_initializers do |app|
  		Minority.load_files.each do |file|
    		require_relative File.join("../..", file)
  		end
    	#Minority.motd
	end
  end
end


