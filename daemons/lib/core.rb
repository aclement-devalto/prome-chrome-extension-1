require_relative 'toolbox'

#----------------------------------------------------------------

	# CUSTOM CONFIG

	# Path to Prome3 on host machine
	PROME_DIR =  ENV['HOME'] + '/Projets/prome3'    # Update this variable with your own local path to Prome

#----------------------------------------------------------------

	# DEFAULT VARIABLES

	# Path to web directory relative
	$web_path = PROME_DIR + '/web'

	# Path to Vagrant SSH key
	$ssh_key = PROME_DIR + "/puphpet/files/dot/ssh/id_rsa"

	# Virtual machine hostname
	$vm_hostname = "192.168.56.101"

	# Absolute path for Prome3 on VM
	$base_path = '/vagrant'

	# Print debug output in terminal
	$debug = true

	# Listening port
	$listening_post = 7500

#----------------------------------------------------------------

require_relative 'commander'

#----------------------------------------------------------------

# Initial config check before launch

# Check Prome base directory
unless File.directory?(PROME_DIR)
	puts(red("Unable to find Prome directory (" + PROME_DIR + ") ! Did you forget to change the default config?"))
	exit
end

# Look for Vagrant SSH key
unless File.exists?($ssh_key)
	puts(red("Unable to find Vagrant SSH key (" + $ssh_key + ") !"))
	exit
end