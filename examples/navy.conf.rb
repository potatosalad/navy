preload do |admiral|
  admiral.logger.warn "admiral preload"
end

before_fork do |admiral, captain|
  admiral.logger.warn "admiral (#{captain.label}) before_fork"
  captain.logger.warn "captain=#{captain.label} before_fork"
end

after_fork do |admiral, captain|
  admiral.logger.warn "admiral (#{captain.label}) after_fork"
  captain.logger.warn "captain=#{captain.label} after_fork"
end

respawn_limit 15, 5

pid "/tmp/navy.pid"

# stderr_path "/tmp/navy-err.log"
# stdout_path "/tmp/navy-out.log"

captain :jack do

  stderr_path "/tmp/navy-jack-err.log"
  stdout_path "/tmp/navy-jack-out.log"

  preload do |captain|
    captain.logger.warn "captain=#{captain.label} preload"
  end

  before_fork do |captain, officer|
    captain.logger.warn "captain=#{captain.label} before_fork"
    officer.logger.warn "(#{captain.label}) officer=#{officer.number} before_fork"
  end

  after_fork do |captain, officer|
    captain.logger.warn "captain=#{captain.label} after_fork"
    officer.logger.warn "(#{captain.label}) officer=#{officer.number} after_fork"
  end

  respawn_limit 15, 5

  officers 2 do |officer|
    trap(:QUIT) { exit }
    trap(:TERM) { exit }
    # raise "HELLO"
    n = 0
    loop do
      Navy.logger.info "#{n} jack called (officer=#{officer.number}) pid: #{officer.officer_pid}"
      # Navy.logger.info "START_CTX: #{START_CTX.inspect}"
      # Navy.logger.info "Navy::Admiral::CAPTAINS: #{Navy::Admiral::CAPTAINS.inspect}"
      # Navy.logger.info "Navy::Admiral::OFFICERS: #{Navy::Captain::OFFICERS.inspect}"
      sleep 1
      n += 1
    end
  end

end

captain :blackbeard do

  pid "/tmp/navy-blackbeard.pid"

  officers 5 do
    trap(:QUIT) { exit }; trap(:TERM) { exit }; loop { sleep 1 }
  end
  # officers 5 do
  #   trap(:QUIT, :TRAP) { exit }

  #   nil while true
  # end

end