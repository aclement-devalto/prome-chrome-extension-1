require 'daemons'
require_relative 'daemons/lib/core'

Daemons.run('daemons/watcher.rb', {:backtrace => true})