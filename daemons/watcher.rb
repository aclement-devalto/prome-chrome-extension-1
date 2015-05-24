require 'logger'
require 'listen'
require_relative 'lib/core'

class Watcher

	def initialize

		# Relative paths
		@paths = {
			:js		=>	'/web/app',
			:sass	=>	'/web/packages'
		}

		#----------------------------------------------------------------

		@logger = Logger.new(File.dirname(__FILE__) + '/logs/watcher.log')

		@commander = Commander.new

		@logger.info("Initializing Watcher")

		# Start Listen to watch added/removed files in specified paths

		# Listeners instance
		@js_listener = Listen.to(PROME_DIR + @paths[:js], only: /\.js$/, wait_for_delay: 4) do |modified, added, removed|
			if added.size > 0 || removed.size > 0
				if $debug
					@logger.debug(" ++ Added files: #{added}")
					@logger.debug(" -- Removed files: #{removed}")
				end

				client = Toolbox.get_current_tenant

				result = @commander.execute('sencha-refresh', client)

				# Debug output
				if $debug
					@logger.info("----------------------------------------------------------------")
					@logger.info("[OUTPUT]")
					@logger.debug(result[:output])
					@logger.info("----------------------------------------------------------------")
				end

				unless result[:error] == ""
					@logger.info("----------------------------------------------------------------")
					@logger.info("[ERROR]")
					@logger.error(result[:error])
					@logger.info("----------------------------------------------------------------")
				end

				@logger.info("Command result: " + result[:result])
			end
		end

		@sass_listener = Listen.to(PROME_DIR + @paths[:sass], only: /\.scss$/, wait_for_delay: 4) do |modified, added, removed|
			if added.size > 0 || removed.size > 0
				if $debug
					@logger.debug(" ++ Added files: #{added}")
					@logger.debug(" -- Removed files: #{removed}")
				end

				client = Toolbox.get_current_tenant

				result = @commander.execute('sencha-ant-sass', client)

				# Debug output
				if $debug
					@logger.info("----------------------------------------------------------------")
					@logger.info("[OUTPUT]")
					@logger.debug(result.inspect)
					@logger.info("----------------------------------------------------------------")
				end

				unless result[:error] == ""
					@logger.info("----------------------------------------------------------------")
					@logger.info("[ERROR]")
					@logger.error(result[:error])
					@logger.info("----------------------------------------------------------------")
				end

				@logger.info("Command result: " + result[:result])
			end
		end

		@js_listener.start
		@sass_listener.start
		sleep
	end
end

watcher = Watcher.new