require 'net/ssh/gateway'
require 'open3'
require 'json'
require 'daemons'
require 'timeout'

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

		{
			:status => exit_code == 0,
			:output => stdout.force_encoding("utf-8"),
			:error => stderr.force_encoding("utf-8")
		}
	end

	#----------------------------------------------------------------

	# Connect to VM via SSH to execute a shell command

	def exec_vm_command(task)
		# Connect to VM using SSH key
		ssh = Net::SSH.start($vm_hostname, "vagrant", {:keys => [$ssh_key]})

		script = "cd " + $base_path + " && " + task[:script]

		response = ssh_exec! ssh, script

		task[:status] = response[:status]
		task[:output] = response[:output]
		task[:error] = response[:error]

		task
	end

	#----------------------------------------------------------------

	# Execute a Sencha command in the web folder

	def exec_sencha_command(task)
		sencha_command = "sencha"

		if task[:client]
			sencha_command += " config -prop app.theme=tenant-" + task[:client] + " then"
		end

		sencha_command += " " + task[:script]

		Dir.chdir($web_path)

		# Execute shell command and retrieve result
		stdout, stderr, exit_status = Open3.capture3(sencha_command)

		task[:status] = exit_status.success?
		task[:output] = stdout.force_encoding("ISO-8859-1").encode("UTF-8")
		task[:error] = stderr.force_encoding("ISO-8859-1").encode("UTF-8")

		task
	end

	#----------------------------------------------------------------

	# Receive command order and process it

	def process(command_alias, tenant)
		# Format alternate version of tenant alias for backend scripts
		camelcase_tenant = tenant.split('-').select { |w| w.capitalize! || w }.join('')

		available_tasks = {
			'create-database' => {
				:alias => 'create-database',
				:script => "php bin/phing create-database",
				:type => 'backend',
				:cancellable => true,
				:wait_for => 'drop-datatabase'
			},
		    'drop-database' => {
			    :alias => 'drop-database',
			    :script => "php bin/console doctrine:database:drop --force",
			    :type => 'backend'
		    },
		    'reset-setup' => {
			    :alias => 'reset-setup',
			    :script => "php bin/console doctrine:database:drop --force"\
			                " && composer install"\
			                " && php bin/phing create-database"\
			                " && php bin/console doctrine:fixtures:load --fixtures=app/DoctrineFixtures/Common --no-interaction -v"\
							" && php bin/console doctrine:fixtures:load --append --fixtures=app/DoctrineFixtures/" + camelcase_tenant + " --no-interaction -v",
			    :type => 'backend',
			    :cancellable => true,
			    :refresh_browser => true
		    },
		    'load-common-fixtures' => {
			    :alias => 'load-common-fixtures',
			    :script => "php bin/console doctrine:fixtures:load --fixtures=app/DoctrineFixtures/Common --no-interaction -v",
			    :type => 'backend',
			    :cancellable => true,
			    :wait_for => 'create-database'
		    },
		    'load-tenant-fixtures' => {
			    :alias => 'load-tenant-fixtures',
			    :script => "php bin/console doctrine:fixtures:load --append --fixtures=app/DoctrineFixtures/" + camelcase_tenant + " --no-interaction -v",
			    :type => 'backend',
			    :cancellable => true,
			    :wait_for => 'load-common-fixtures'
		    },
		    'clear-cache' => {
			    :alias => 'clear-cache',
				:script => "php bin/console cache:clear --env=dev",
			    :type => 'backend'
		    },
		    'sencha-build' => {
			    :alias => 'sencha-build',
			    :script => "app build --clean",
			    :type => 'frontend',
			    :client => tenant,
			    :cancellable => true,
			    :refresh_browser => true
		    },
		    'sencha-resources' => {
			    :alias => 'sencha-resources',
			    :script => "ant resources",
			    :type => 'frontend',
			    :client => tenant,
			    :cancellable => true,
			    :refresh_browser => true
		    },
			'sencha-refresh' => {
				:alias => 'sencha-refresh',
				:script => "app refresh",
				:type => 'frontend',
				:client => tenant,
				:cancellable => true,
				:refresh_browser => true
			},
		    'sencha-build-js' => {
			    :alias => 'sencha-build-js',
			    :script => "ant js",
			    :type => 'frontend',
			    :client => tenant,
			    :cancellable => true,
			    :refresh_browser => true
		    },
		    'sencha-ant-sass' => {
			    :alias => 'sencha-ant-sass',
			    :script => "ant sass",
			    :type => 'frontend',
			    :client => tenant,
			    :cancellable => true,
			    :refresh_browser => true
		    }
		}

		if available_tasks[command_alias]
			# Save task to DB
			task = available_tasks[command_alias]

			execute(task)
		else
			@logger.error("Unknown command received: " + command_alias)
			"Unknown command: " + command_alias

			false
		end
	end

	#----------------------------------------------------------------

	# Stop an ongoing task

	def kill_task(task)
		unless task[:pid].nil?
			begin
				Process.kill((RUBY_PLATFORM =~ /win32/ ? 'KILL' : 'TERM'), task[:pid])

				# Update task status as manually killed
				@tasks.where(:id => task[:id]).update(:status => false, :pid => nil, :killed => true)

				true
			rescue Errno::ESRCH
				# Update task status as manually killed
				@tasks.where(:id => task[:id]).update(:status => false, :pid => nil, :killed => true)

				false
			end
		end
	end

	#----------------------------------------------------------------

	# Execute a task command

	def execute (task)
		if task[:type] === 'backend'
			exec_vm_command(task)
		else
			exec_sencha_command(task)
		end
	end
end