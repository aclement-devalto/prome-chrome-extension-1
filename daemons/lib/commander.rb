require 'net/ssh/gateway'
require 'open3'
require 'json'

class Commander

	def initialize
		@logger = Logger.new(File.dirname(__FILE__) + '/../logs/commander.log')

		@logger.info("Initializing Commander")
	end

	#----------------------------------------------------------------

	# SSH exec

	def ssh_exec!(ssh, command)
		stdout = ""
		stderr = ""
		exit_code = nil
		exit_signal = nil

		# Execute shell command in opened SSH tunnel connection
		ssh.open_channel do |channel|
			channel.exec(command) do |ch, success|
				unless success
					@logger.error("FAILED: couldn't execute command (ssh.channel.exec)")
					abort
				end

				channel.on_data do |ch, data|
					stdout+=data
				end

				channel.on_extended_data do |ch, type, data|
					stderr+=data
				end

				channel.on_request("exit-status") do |ch, data|
					exit_code = data.read_long
				end

				channel.on_request("exit-signal") do |ch, data|
					exit_signal = data.read_long
				end
			end
		end
		ssh.loop

		# Debug output
		if $debug
			@logger.info("----------------------------------------------------------------")
			@logger.info("[OUTPUT]")
			@logger.debug(stdout)
			@logger.info("----------------------------------------------------------------")
		end

		unless stderr == ""
			@logger.info("----------------------------------------------------------------")
			@logger.info("[ERROR]")
			@logger.error(stderr)
			@logger.info("----------------------------------------------------------------")
		end

		@logger.info("Exit status: " + exit_code.to_s)

		{:result => exit_code, :output => stdout.force_encoding("utf-8"), :error => stderr.force_encoding("utf-8")}
	end

	#----------------------------------------------------------------

	# Connect to VM via SSH to execute a shell command

	def exec_vm_command(command)
		# Connect to VM using SSH key
		ssh = Net::SSH.start($vm_hostname, "vagrant", {:keys => [$ssh_key]})

		command = "cd " + $base_path + " && " + command

		result = ssh_exec! ssh, command
	end

	#----------------------------------------------------------------

	# Execute a Sencha command in the web folder

	def exec_sencha_command(command, client)
		sencha_command = "sencha"

		if client
			sencha_command += " config -prop app.theme=tenant-" + client + " then"
		end

		sencha_command += " " + command

		Dir.chdir($web_path)

		# Execute shell command and retrieve result
		stdout, stderr, exit_status = Open3.capture3(sencha_command)

		# Debug output
		if $debug
			@logger.info("----------------------------------------------------------------")
			@logger.info("[OUTPUT]")
			@logger.debug(stdout)
			@logger.info("----------------------------------------------------------------")
		end

		unless stderr == ""
			@logger.info("----------------------------------------------------------------")
			@logger.info("[ERROR]")
			@logger.error(stderr)
			@logger.info("----------------------------------------------------------------")
		end

		@logger.info("Exit status: " + exit_status.exitstatus.to_s)

		{:result => exit_status.success?, :output => stdout, :error => stderr}
	end

	#----------------------------------------------------------------

	def execute(command_name, client)
		if $debug
			@logger.info("Executing " + command_name + " for client " + client)
		end

		case command_name
			when 'create-database'
				command = "php bin/phing create-database"

				exec_vm_command(command).to_json

			when 'drop-database'
				exec_vm_command("php bin/console doctrine:database:drop --force").to_json

			when 'reset-setup'
				command = "php bin/console doctrine:database:drop --force"
				command += " && composer install"
				command += " && php bin/phing create-database"
				command += " && php bin/console doctrine:fixtures:load --fixtures=app/DoctrineFixtures/Common --no-interaction -v"

				if client
					client = client.split('-').select { |w| w.capitalize! || w }.join('');
					command += " && php bin/console doctrine:fixtures:load --append --fixtures=app/DoctrineFixtures/" + client + " --no-interaction -v"
				end

				exec_vm_command(command).to_json

			when 'load-common-fixtures'
				command = "php bin/console doctrine:fixtures:load --fixtures=app/DoctrineFixtures/Common --no-interaction -v"

				exec_vm_command(command).to_json

			when 'load-tenant-fixtures'
				if client
					client = client.split('-').select { |w| w.capitalize! || w }.join('');
					command = "php bin/console doctrine:fixtures:load --append --fixtures=app/DoctrineFixtures/" + client + " --no-interaction -v"
				else
					client = "AdraAus"
					command = "php bin/console doctrine:fixtures:load --append --fixtures=app/DoctrineFixtures/" + client + " --no-interaction -v"
				end

				exec_vm_command(command).to_json

			when 'clear-cache'
				exec_vm_command("php bin/console cache:clear --env=dev").to_json

			when 'sencha-build'
				exec_sencha_command("app build --clean", client).to_json

			when 'sencha-resources'
				exec_sencha_command("ant resources", client).to_json

			when 'sencha-refresh'
				exec_sencha_command("app refresh", client).to_json

			when 'sencha-build-js'
				exec_sencha_command("ant js", client).to_json

			when 'sencha-ant-sass'
				exec_sencha_command("ant sass", client).to_json

			else
				@logger.error("Unknown command received: " + command_name)
				"Unknown command: " + command_name
		end
	end
end