require 'logger'
require 'json'
require 'sinatra/base'
require 'sinatra-websocket'
require 'terminal-notifier'

require_relative 'lib/core'

class Listener < Sinatra::Application

	# HTTP response headers
	before do
		content_type :json, 'charset' => 'utf-8'

		# CORS headers needed for Chrome extension
		headers 'Access-Control-Allow-Origin' => '*',
		        'Access-Control-Allow-Methods' => ['OPTIONS', 'GET', 'POST']
	end

	# Sinatra config
	set :protection, false
	set :port, $listening_port
	set :server, 'thin'
	set :sockets, []

	def initialize
		super

		@logger = Logger.new(File.dirname(__FILE__) + '/logs/listener.log')

		@commander = Commander.new

		# Everything OK
		@logger.info("Listener launched from directory " + PROME_DIR)
	end

	get '/execute/:command' do
		stream do |out|
			if $debug
				@logger.debug("Command received for tenant " + params['client'] + ': ' + params['command'])
			end

			command_result = @commander.execute(params['command'], params['client'])
			out << command_result.to_json

			tenant_name = Toolbox.get_tenant_name(params['client'])

			case params['command']
				when 'create-database'
					notification = {
						:success => 'Created database',
						:error => 'Database creation failed'
					}

				when 'drop-database'
					notification = {
						:success => 'Dropped database',
						:error => 'Database drop failed'
					}

				when 'reset-setup'
					notification = {
						:success => 'Reset development setup',
						:error => 'Setup reset failed'
					}

				when 'load-common-fixtures'
					notification = {
						:success => 'Loaded common fixtures into database',
						:error => 'Common fixtures loading failed'
					}

				when 'load-tenant-fixtures'
					notification = {
						:success => "Loaded #{tenant_name} fixtures into database",
						:error => "#{tenant_name} fixtures loading failed"
					}

				when 'clear-cache'
					notification = {
						:success => 'Cleared cache',
						:error => 'Failed to clear cache'
					}

				when 'sencha-build'
					notification = {
						:success => 'Completed front-end build',
						:error => 'Front-end build failed'
					}

				when 'sencha-resources'
					notification = {
						:success => 'Copied front-end resources',
						:error => 'Failed to copy resources'
					}

				when 'sencha-refresh'
					notification = {
						:success => 'Refreshed Javascript files index',
						:error => 'Javascript files index failed'
					}

				when 'sencha-build-js'
					notification = {
						:success => 'Completed Javascript build',
						:error => 'Javascript build failed'
					}

				when 'sencha-ant-sass'
					notification = {
						:success => 'Completed SASS compilation',
						:error => 'SASS compilation failed'
					}
			end

			if notification
				if command_result[:result]
					TerminalNotifier.notify(notification[:success],
					                        :title => 'Prome 3 - ' + tenant_name)
				else
					TerminalNotifier.notify(notification[:error],
					                        :title => 'Prome 3 - ' + tenant_name)
				end
			end
		end
	end

	get '/socket' do
		if request.websocket?
			request.websocket do |ws|
				ws.onopen do
					settings.sockets << ws
				end
				ws.onmessage do |msg|
					EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
				end
				ws.onclose do
					settings.sockets.delete(ws)
				end
			end
		end
	end

	# UNUSED
	post '/git-checkout' do
		EM.next_tick {
			# Notify each sockets of the Git checkout
			settings.sockets.each{|s| s.send('git-checkout') }
		}
	end

	# UNUSED
	post '/git-merge' do
		EM.next_tick {
			# Notify each sockets of the Git merge
			settings.sockets.each{|s| s.send('git-checkout') }
		}
	end

	post '/watcher-rebuild' do
		case params['type']
			when 'js'
				notification = {
					:title => 'Javascript files change detected',
				    :subtitle => 'Refreshed Javascript files index'
				}
			when 'sass'
				notification = {
					:title => 'SCSS files update detected',
					:subtitle => 'Completed SASS compilation'
				}
		end

		if notification
			TerminalNotifier.notify(notification[:subtitle],
			                        :title => 'Prome 3 - ' + Toolbox.get_tenant_name(params['tenant']),
			                        :subtitle => notification[:title])
		end

		if params['refresh'] == 'true'
			EM.next_tick {
				# Notify each sockets of the rebuild
				settings.sockets.each{|s| s.send(
					{
						:action => 'watcher-rebuild',
						:type => params['type'],
					    :tenant => params['tenant']
					}.to_json
				)}
			}
		end
	end

	get '/ping' do
		content_type :text
		"Commander is up and running!"
	end

	run!
end

listener = Listener.new