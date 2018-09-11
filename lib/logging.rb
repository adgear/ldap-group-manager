# frozen_string_literal: true

# The global logging instance. Uses the <code>Ougai</code> JSON structured
# logger.
# @since 0.1.0
module AdGear::Infrastructure::GroupManager::Logging
  require('ougai')

  # The global logging instance
  if ENV['AG_LOG_FORMAT'] =~ /json/i
    Log = Ougai::Logger.new(STDOUT)
  else
    Log = Ougai::Logger.new(STDERR)
    Log.formatter = Ougai::Formatters::Readable.new
  end

  Log.level = ENV['LOG_LEVEL'] || 'info'

  module_function

  # A helper method that allows to log an error and exit.
  # @param [Array] args passes all arguments, as is, to Ougai.
  # @return [nil] no return.
  # @since 0.1.0
  def fatal(*args)
    Log.error(*args)
    exit(1)
  end
end
