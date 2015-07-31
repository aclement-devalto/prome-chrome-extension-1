require 'logger'
require 'json'
require 'sinatra/base'
require 'sinatra-websocket'
require 'terminal-notifier'

require_relative 'lib/core'

class Dispatcher < Sinatra::Application

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

		@logger = Logger.new(File.dirname(__FILE__) + '/logs/dispatcher.log')

		@commander = Commander.new

		# Everything OK
		@logger.info("Listener launched from directory " + PROME_DIR)
	end

	get '/command' do
		if request.websocket?
			request.websocket do |ws|
				ws.onopen do
					settings.sockets << ws
				end
				ws.onmessage do |message|
					# Socket expects JSON encoded command messages containing 'command' & 'tenant' properties
					params = JSON.parse(message)

					@logger.info("Command received from socket (execute) " + message)

					# Check if command parameter is defined
					if params['command']
						Thread.new {
							EM.run do
								result = @commander.process(params['command'], params['tenant'])
								@logger.info("Command complete: " + result['status'].to_s)

								EM.next_tick {
									@logger.info("Response sent back to socket: " + result['status'].to_s)

									ws.send(result.to_json)
								}
							end
						}
					else
						result = {
							'status' => false,
							'error' => 'Missing command parameter'
						}

						EM.next_tick {
							@logger.info("Response sent back to socket: " + result['error'])

							ws.send(result.to_json)
						}
					end
				end
				ws.onclose do
					settings.sockets.delete(ws)
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
					@logger.info("Message received from socket " + msg)
					#EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
				end
				ws.onclose do
					settings.sockets.delete(ws)
				end
			end
		end
	end

	get '/ping' do
		content_type :text
		"Commander is up and running!"
	end

	run!
end

dispatcher = Dispatcher.new