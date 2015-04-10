#!/usr/bin/ruby

require 'sinatra'
require 'json'
require 'open3'
require 'net/ssh/gateway'
require 'net/scp'

#----------------------------------------------------------------
  
  # Path to Prome3 on host machine
  prome_dir =  ENV['HOME'] + '/Projets/prome3'
  # Path to web directory relative
  $web_path = prome_dir + '/web'
  # Path to Vagrant SSH key
  $ssh_key = prome_dir + "/puphpet/files/dot/ssh/id_rsa"
  # Absolute path for Prome3 on VM
  $base_path = '/vagrant'
  # Print debug output in terminal
  $debug = false

#----------------------------------------------------------------
  
  # HTTP response headers
  before do
     content_type :json, 'charset' => 'utf-8'

     # CORS headers needed for Chrome extension
     headers 'Access-Control-Allow-Origin' => '*',
             'Access-Control-Allow-Methods' => ['OPTIONS', 'GET', 'POST']
  end

  # Sinatra config
  set :protection, false
  set :port, 7500

#----------------------------------------------------------------

  # Connect to VM via SSH to execute a shell command

  def exec_vm_command(command)
    # Connect to VM using SSH key
    ssh = Net::SSH.start("192.168.56.101", "vagrant", {:keys => [$ssh_key]})

    command = "cd " + $base_path + " && " + command

    result = ssh_exec! ssh, command
  end

#----------------------------------------------------------------

  # SSH exec

  def ssh_exec!(ssh, command)
      stdout = ""
      stderr = ""
      exit_code = nil
      exit_signal = nil

      if $debug then
        puts "----------------------------------------------------------------"
        puts command
      end

      # Execute shell command in opened SSH tunnel connection
      ssh.open_channel do |channel|
        channel.exec(command) do |ch, success|
          unless success
            abort "FAILED: couldn't execute command (ssh.channel.exec)"
          end

          channel.on_data do |ch,data|
            stdout+=data
          end

          channel.on_extended_data do |ch,type,data|
            stderr+=data
          end

          channel.on_request("exit-status") do |ch,data|
            exit_code = data.read_long
          end

          channel.on_request("exit-signal") do |ch, data|
            exit_signal = data.read_long
          end
        end
      end
      ssh.loop

      # Debug output
      if $debug then
        puts "----------------------------------------------------------------"
        puts stdout
        puts "----------------------------------------------------------------"
        puts stderr
        puts "----------------------------------------------------------------"
        puts exit_code
        puts "----------------------------------------------------------------"
      end

      {:result => !!exit_code, :output => stdout.force_encoding("utf-8"), :error => stderr.force_encoding("utf-8")}
  end

#----------------------------------------------------------------
  
  # Execute a Sencha command in the web folder

  def exec_sencha_command(command, client)
    sencha_command = "sencha"

    if client then
      sencha_command += " config -prop app.theme=tenant-" + client + " then"
    end

    sencha_command += " " + command

    Dir.chdir($web_path)

    # Debug output
    if $debug then
      puts "----------------------------------------------------------------"
      puts sencha_command
    end

    # Execute shell command and retrieve result
    stdout, stderr, exit_status = Open3.capture3(sencha_command)

    # Debug output
    if $debug then
      puts "----------------------------------------------------------------"
      puts stdout
      puts "----------------------------------------------------------------"
      puts stderr
      puts "----------------------------------------------------------------"
      puts exit_status
      puts "----------------------------------------------------------------"
    end

    {:result => exit_status.success?, :output => stdout, :error => stderr}
  end

#----------------------------------------------------------------

  # Convert ANSI styling to HTML

  def ansi_to_html(data)
    { 1 => :nothing,
      2 => :nothing,
      4 => :nothing,
      5 => :nothing,
      7 => :nothing,
      30 => :black,
      31 => :red,
      32 => :green,
      33 => :yellow,
      34 => :blue,
      35 => :magenta,
      36 => :cyan,
      37 => :white,
      40 => :nothing,
      41 => :nothing,
      43 => :nothing,
      44 => :nothing,
      45 => :nothing,
      46 => :nothing,
      47 => :nothing,
      90 => :grey
    }.each do |key, value|
      if value != :nothing
        data.gsub!(/\e\[00;#{key}m/,"<span style=\"color: #{value}\">")
      else
        data.gsub!(/\e\[#{key}m/,"<span>")
      end
    end
    data.gsub!(/\e\[0m/,'</span>')
    data.gsub!(/\n/, '<br>')

    return data
  end

#----------------------------------------------------------------

get '/execute/:command' do
  client = params['client']

  case params['command']
  when 'create-database'
    command = "php bin/console doctrine:database:create"
    command += " && php bin/console doctrine:migrations:migrate --no-interaction"

    exec_vm_command(command).to_json

  when 'drop-database'
    exec_vm_command("php bin/console doctrine:database:drop --force").to_json

  when 'reset-setup'
    command = "php bin/console doctrine:database:drop --force"
    command += " && composer install"
    command += " && php bin/console doctrine:database:create"
    command += " && php bin/console doctrine:migrations:migrate --no-interaction"
    command += " && php bin/console doctrine:fixtures:load --fixtures=app/DoctrineFixtures/Common --no-interaction -v"

    if client
      client = client.split('-').select {|w| w.capitalize! || w }.join('');
      command += " && php bin/console doctrine:fixtures:load --append --fixtures=app/DoctrineFixtures/" + client + " --no-interaction -v"
    end

    exec_vm_command(command).to_json

  when 'load-fixtures'
    if client
      client = client.split('-').select {|w| w.capitalize! || w }.join('');
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
    "Unknown command: " + params['command']
  end
end

get '/ping' do
  content_type :text
  "Commander is up and running!"
end