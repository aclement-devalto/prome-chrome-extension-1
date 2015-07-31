require 'net/ssh/gateway'
require 'open3'
require 'json'
require 'daemons'
require 'timeout'
require 'yaml'

class Commander
	def initialize
		@logger = Logger.new(File.dirname(__FILE__) + '/../logs/commander.log')

		@logger.info("Initializing Commander")

		# Load available tasks
		@available_tasks = YAML.load_file(File.dirname(__FILE__) + '/../../config/tasks.yml')
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
		# Format alternate version of tenant alias for backend scripts
		camelcase_tenant = task['tenant'].split('-').select { |w| w.capitalize! || w }.join('')

		# Connect to VM using SSH key
		ssh = Net::SSH.start($vm_hostname, "vagrant", {:keys => [$ssh_key]})

		script = "cd " + $base_path + " && " + task['script'].gsub('{tenant}', camelcase_tenant)

		response = ssh_exec! ssh, script

		task['status'] = response['status']
		task['output'] = response['output']
		task['error'] = response['error']

		task
	end

	#----------------------------------------------------------------

	# Execute a Sencha command in the web folder

	def exec_sencha_command(task)
		sencha_command = "sencha config -prop app.theme=tenant-" + task['tenant'] + " then"

		sencha_command += " " + task['script']

		Dir.chdir($web_path)

		# Execute shell command and retrieve result
		stdout, stderr, exit_status = Open3.capture3(sencha_command)

		task['status'] = exit_status.success?
		task['output'] = stdout.force_encoding("ISO-8859-1").encode("UTF-8")
		task['error'] = stderr.force_encoding("ISO-8859-1").encode("UTF-8")

		task
	end

	#----------------------------------------------------------------

	# Receive command order and process it

	def process(command_alias, tenant)
		task = find_task_by_alias(command_alias)

		if task.nil?
			@logger.error("Unknown command received: " + command_alias)

			false
		else
			task['tenant'] = tenant

			@logger.error("Command: " + task.inspect)

			execute(task)
		end
	end

	#----------------------------------------------------------------

	# Stop an ongoing task

	def kill_task(task)
		unless task['pid'].nil?
			begin
				Process.kill((RUBY_PLATFORM =~ /win32/ ? 'KILL' : 'TERM'), task['pid'])

				# Update task status as manually killed
				#@tasks.where(:id => task[:id]).update(:status => false, :pid => nil, :killed => true)

				true
			rescue Errno::ESRCH
				# Update task status as manually killed
				#@tasks.where(:id => task[:id]).update(:status => false, :pid => nil, :killed => true)

				false
			end
		end
	end

	#----------------------------------------------------------------

	# Execute a task command

	def execute (task)
		if task['type'] === 'backend'
			exec_vm_command(task)
		else
			exec_sencha_command(task)
		end
	end

	def find_task_by_alias(requested_alias)
		@available_tasks.each do |category_key, category|
			category['tasks'].each do |task_alias, task|
				if requested_alias == task_alias
					return task
				end
			end
		end

		return nil
	end
end