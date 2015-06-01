require 'json'

module Toolbox

	#----------------------------------------------------------------

	# Define text output colours

	def self.colorize(text, color_code)
		"\e[#{color_code}m#{text}\e[0m"
	end

	#----------------------------------------------------------------

	# Convert ANSI styling to HTML

	def ansi_to_html(data)
		{
			1 => :nothing,
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
				data.gsub!(/\e\[00;#{key}m/, "<span style=\"color: #{value}\">")
			else
				data.gsub!(/\e\[#{key}m/, "<span>")
			end
		end
		data.gsub!(/\e\[0m/, '</span>')
		data.gsub!(/\n/, '<br>')

		data
	end

	#----------------------------------------------------------------

	# Find current build tenant

	def self.get_current_tenant
		file = File.read($web_path + '/bootstrap.json')
		bootstrap_config = JSON.parse(file)

		if !bootstrap_config['packages']['tenant-adra-aus'].nil?
			"adra-aus"
		else
			"undp-mwi"
		end
	end

	def self.get_tenant_name(tenant_alias)
		tenant_alias.split('-').first.upcase
	end
end

#----------------------------------------------------------------

def red(text)
	Toolbox.colorize(text, 31)
end

def green(text)
	Toolbox.colorize(text, 32)
end

def yellow(text)
	Toolbox.colorize(text, 33)
end

def blue(text)
	Toolbox.colorize(text, 34)
end