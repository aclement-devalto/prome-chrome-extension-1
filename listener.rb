require 'daemons'
require_relative 'daemons/lib/core'

Daemons.run('daemons/listener.rb', {:backtrace => true})