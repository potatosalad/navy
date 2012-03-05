class Navy::Admiral::Orders < Navy::Orders

  defaults.merge!({
    after_fork: ->(admiral, captain) do
      admiral.logger.info("captain=#{captain.label} spawned pid=#{$$}")
    end,
    before_fork: ->(admiral, captain) do
      admiral.logger.info("captain=#{captain.label} spawning...")
    end,
    before_exec: ->(admiral) do
      admiral.logger.info("forked child re-executing...")
    end,
    captains: {},
    preload: ->(admiral) do
      admiral.logger.info("admiral preloading...")
    end,
    respawn_limit: 100,
    respawn_limit_seconds: 1.0
  })

end
require 'navy/admiral/speak'