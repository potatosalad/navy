class Navy::Admiral::Orders < Navy::Orders

  defaults.merge!({
    after_fork: ->(admiral, captain) do
      admiral.logger.info("captain=#{captain.label} spawned pid=#{$$}")
    end,
    after_stop: ->(admiral, graceful) do
      admiral.logger.debug("admiral after (#{graceful ? 'graceful' : 'hard'}) stop") if $DEBUG
    end,
    before_fork: ->(admiral, captain) do
      admiral.logger.info("captain=#{captain.label} spawning...")
    end,
    before_exec: ->(admiral) do
      admiral.logger.info("forked child re-executing...")
    end,
    before_stop: ->(admiral, graceful) do
      admiral.logger.debug("admiral before (#{graceful ? 'graceful' : 'hard'}) stop") if $DEBUG
    end,
    captains: {},
    heartbeat: ->(admiral) do
      admiral.logger.debug("admiral heartbeat") if $DEBUG
    end,
    post_fork: ->(admiral, captain) do
      admiral.logger.debug("captain=#{captain.label} post-fork") if $DEBUG
    end,
    preload: ->(admiral) do
      admiral.logger.info("admiral preloading...")
    end,
    respawn_limit: 100,
    respawn_limit_seconds: 1.0
  })

end
require 'navy/admiral/speak'