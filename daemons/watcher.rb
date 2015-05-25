require 'logger'
require 'listen'
require 'net/http'
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

				# Notify listener of the rebuild
				uri = URI('http://localhost:' + $listening_port.to_s + '/watcher-rebuild')
				res = Net::HTTP.post_form(uri, 'type' => 'js')
			end
		end

		@sass_listener = Listen.to(PROME_DIR + @paths[:sass], only: /\.scss$/, wait_for_delay: 5) do |modified, added, removed|
			if $debug
				@logger.debug(" ++ Added files: #{added}")
				@logger.debug(" ** Modified files: #{modified}")
				@logger.debug(" -- Removed files: #{removed}")
			end

			client = Toolbox.get_current_tenant

			result = @commander.execute('sencha-ant-sass', client)

			# Notify listener of the rebuild
			uri = URI('http://localhost:' + $listening_port.to_s + '/watcher-rebuild')
			res = Net::HTTP.post_form(uri, 'type' => 'sass')
		end

		@js_listener.start
		@sass_listener.start
		sleep
	end
end

watcher = Watcher.new