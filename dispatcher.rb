require 'daemons'
require_relative 'daemons/lib/core'

Daemons.run('daemons/dispatcher.rb', {:backtrace => true})