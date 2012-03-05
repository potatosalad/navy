require 'navy/version'

require 'fcntl'
require 'etc'
require 'stringio'
require 'kgio'

require 'forwardable'
require 'logger'

module Navy
  extend self
  def logger
    @logger ||= Logger.new($stderr)
  end

  def log_error(logger, prefix, exc)
    message = exc.message
    message = message.dump if /[[:cntrl:]]/ =~ message
    logger.error "#{prefix}: #{message} (#{exc.class})"
    exc.backtrace.each { |line| logger.error(line) }
  end
end
require 'navy/util'
require 'navy/orders'
require 'navy/rank'
require 'navy/admiral'
require 'navy/captain'
require 'navy/officer'