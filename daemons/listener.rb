require 'logger'
require 'sinatra/base'

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
	set :port, $listening_post
	set :server, 'thin'

	def initialize
		super

		@logger = Logger.new(File.dirname(__FILE__) + '/logs/listener.log')

		@commander = Commander.new

		# Everything OK
		@logger.info("Listener launched from directory " + PROME_DIR)
	end

	get '/execute/:command' do
		if $debug
			@logger.debug("Command received for tenant " + params['client'] + ': ' + params['command'])
		end

		@commander.execute(params['command'], params['client'])
	end

	get '/ping' do
		content_type :text
		"Commander is up and running!"
	end

	run!
end

listener = Listener.new