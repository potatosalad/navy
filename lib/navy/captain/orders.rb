class Navy::Captain::Orders < Navy::Orders

  defaults.merge!({
    after_fork: ->(captain, officer) do
      captain.logger.info("(#{captain.label}) officer=#{officer.number} spawned pid=#{$$}")
    end,
    after_stop: ->(captain, graceful) do
      captain.logger.debug("captain=#{captain.label} after (#{graceful ? 'graceful' : 'hard'}) stop") if $DEBUG
    end,
    before_fork: ->(captain, officer) do
      captain.logger.info("(#{captain.label}) officer=#{officer.number} spawning...")
    end,
    before_stop: ->(captain, graceful) do
      captain.logger.debug("captain=#{captain.label} before (#{graceful ? 'graceful' : 'hard'}) stop") if $DEBUG
    end,
    heartbeat: ->(captain) do
      captain.logger.debug("captain=#{captain.label} heartbeat") if $DEBUG
    end,
    officer_job: -> { trap(:QUIT) { exit }; trap(:TERM) { exit }; loop { sleep 1 } },
    officer_count: 0,
    officer_fire_and_forget: false,
    patience: 30,
    post_fork: ->(captain, officer) do
      captain.logger.debug("(#{captain.label}) officer=#{officer.number} post-fork") if $DEBUG
    end,
    preload: ->(captain) do
      captain.logger.info("captain=#{captain.label} preloading...")
    end,
    respawn_limit: 100,
    respawn_limit_seconds: 1.0,
    timeout: 30
  })

end
require 'navy/captain/speak'