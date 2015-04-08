#!/usr/bin/ruby

prome_dir =  ENV['HOME'] + '/Projets/prome3'
web_path = prome_dir + '/web'

require 'sinatra'
require 'json'
require 'open3'

before do
   content_type :json, 'charset' => 'utf-8'
   headers 'Access-Control-Allow-Origin' => '*',
           'Access-Control-Allow-Methods' => ['OPTIONS', 'GET', 'POST']
end

set :protection, false

set :port, 7500

def exec_command(command, path)
  Dir.chdir(path)

  command.gsub("php bin/phing", "vendor/phing/phing/bin/phing")

  stdout, stderr, exit_status = Open3.capture3(command)

  {:result => exit_status.success?, :output => ansi_to_html(stdout), :error => ansi_to_html(stderr)}
end

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

get '/execute/:command' do
  client = params['client']

  case params['command']
  when 'create-database'
    exec_command("php bin/phing create-database", prome_dir).to_json
  when 'drop-database'
    exec_command("php bin/phing drop-database", prome_dir).to_json
  when 'reset-setup'
    command = "php bin/phing reset-setup"

    if client
      client = client.split('-').select {|w| w.capitalize! || w }.join('');
      command += " -Dfixture.set=" + client
    end

    exec_command(command, prome_dir).to_json
  when 'load-fixtures'
    command = "php bin/phing load-specific-fixtures"

    if client
      client = client.split('-').select {|w| w.capitalize! || w }.join('');
      command += " -Dfixture.set=" + client
    end
    
    exec_command(command, prome_dir).to_json
  when 'clear-cache'
    exec_command("php bin/console cache:clear --env=dev", prome_dir).to_json
  when 'sencha-build'
    command = "php bin/phing sencha-build"

    if client
      command += " -Dsencha-cmd.tenant.properties=packages/tenant-" + client + "/tenant.properties"
    end

    exec_command(command, prome_dir).to_json
  when 'sencha-resources'
    command = "php bin/phing sencha-resources"
    
    if client
      command += " -Dsencha-cmd.tenant.properties=packages/tenant-" + client + "/tenant.properties"
    end

    exec_command(command, prome_dir).to_json
  when 'sencha-refresh'
    command = "php bin/phing sencha-refresh"
    
    if client
      command += " -Dsencha-cmd.tenant.properties=packages/tenant-" + client + "/tenant.properties"
    end

    exec_command(command, prome_dir).to_json
  when 'sencha-build-js'
    command = "php bin/phing sencha-js"
    
    if client
      command += " -Dsencha-cmd.tenant.properties=packages/tenant-" + client + "/tenant.properties"
    end

    exec_command(command, prome_dir).to_json
  when 'sencha-ant-sass'
    command = "php bin/phing sencha-sass"
    
    if client
      command += " -Dsencha-cmd.tenant.properties=packages/tenant-" + client + "/tenant.properties"
    end

    exec_command(command, prome_dir).to_json
  else
    "Unknown command: " + params['command']
  end
end

get '/ping' do
  content_type :text
  "Commander is up and running!"
end