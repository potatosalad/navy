class Navy::Captain::Orders < Navy::Orders

  defaults.merge!({
    after_fork: ->(captain, officer) do
      captain.logger.info("(#{captain.label}) officer=#{officer.number} spawned pid=#{$$}")
    end,
    before_fork: ->(captain, officer) do
      captain.logger.info("(#{captain.label}) officer=#{officer.number} spawning...")
    end,
    officer_job: -> { trap(:QUIT) { exit }; trap(:TERM) { exit }; loop { sleep 1 } },
    officer_count: 0,
    preload: ->(captain) do
      captain.logger.info("captain=#{captain.label} preloading...")
    end,
    respawn_limit: 100,
    respawn_limit_seconds: 1.0,
    timeout: 30
  })

end
require 'navy/captain/speak'