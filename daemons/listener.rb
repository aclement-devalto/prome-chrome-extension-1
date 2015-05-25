require 'logger'
require 'sinatra/base'
require 'sinatra-websocket'

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

			out << @commander.execute(params['command'], params['client'])
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

	post '/git-checkout' do
		EM.next_tick {
			# Notify each sockets of the Git checkout
			settings.sockets.each{|s| s.send('git-checkout') }
		}
	end

	post '/git-merge' do
		EM.next_tick {
			# Notify each sockets of the Git merge
			settings.sockets.each{|s| s.send('git-checkout') }
		}
	end

	post '/watcher-rebuild' do
		EM.next_tick {
			# Notify each sockets of the rebuild
			settings.sockets.each{|s| s.send('watcher-rebuild-' + params['type']) }
		}
	end

	get '/ping' do
		content_type :text
		"Commander is up and running!"
	end

	run!
end

listener = Listener.new