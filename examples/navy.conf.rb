preload do |admiral|
  # require 'rainbow'
  admiral.logger.warn "admiral preload"
end

before_fork do |admiral, captain|
  admiral.logger.warn "admiral (#{captain.label}) before_fork"
  captain.logger.warn "captain=#{captain.label} before_fork"
end

after_fork do |admiral, captain|
  captain.logger.warn "admiral (#{captain.label}) after_fork"
  captain.logger.warn "captain=#{captain.label} after_fork"
end

respawn_limit 15, 5

pid "/tmp/navy.pid"

# stderr_path "/tmp/navy-err.log"
# stdout_path "/tmp/navy-out.log"

module Jack
  extend self

  def call(officer)
    trap(:QUIT) { exit }
    trap(:TERM) { exit }
    # raise "HELLO"
    n = 0
    loop do
      puts "#{n} jack called (officer=#{officer.number}) pid: #{officer.officer_pid}"
      # Jack.logger.info "#{n} jack logger (officer=#{officer.number}) pid: #{officer.officer_pid}"
      # Navy.logger.info "START_CTX: #{START_CTX.inspect}"
      # Navy.logger.info "Navy::Admiral::CAPTAINS: #{Navy::Admiral::CAPTAINS.inspect}"
      # Navy.logger.info "Navy::Admiral::OFFICERS: #{Navy::Captain::OFFICERS.inspect}"
      sleep officer.number == 0 ? 0.5 : 1
      n += 1
    end
  end

  def logger#(name = nil)
    require 'logger'
    # @logger = nil if name
    @logger ||= Logger.new('/tmp/jack.log')
  end

  def readers
    @readers ||= []
  end

  def reader=(val)
    (@reader = val).tap do |r|
      readers.push(r)
    end
  end

  def writer=(val)
    @writer = val
  end

  def reader
    @reader
  end

  def writer
    @writer
  end
end

captain :jack do

  stderr_path "/tmp/navy-jack-err.log"
  # stdout_path "/tmp/navy-jack-out.log"

  preload do |captain|
    captain.logger.warn "captain=#{captain.label} preload"
    # Jack.mutex.synchronize do
    Jack.logger.info "preload"
    # end
    Thread.new do
      loop do
        rs, ws = IO.select(Jack.readers, [], [], 1)
        (rs || []).each do |r|
          data = r.gets
          next unless data
          data.force_encoding("BINARY") if data.respond_to?(:force_encoding)
          # ps, message = data.split(",", 2)
          # color = colors[ps.split(".").first]
          # info message, ps, color
          # Jack.mutex.synchronize do
            Jack.logger.info data.strip
          # end
        end
      end
    end
  end

  before_fork do |captain, officer|
    captain.logger.warn "captain=#{captain.label} before_fork"
    officer.logger.warn "(#{captain.label}) officer=#{officer.number} before_fork"
    Jack.reader, Jack.writer = IO.pipe
    Jack.reader.sync = true
  end

  after_fork do |captain, officer|
    Jack.reader.close # we don't read
    Jack.writer.sync = true
    captain.logger.warn "captain=#{captain.label} after_fork"
    officer.logger.warn "(#{captain.label}) officer=#{officer.number} after_fork"
    $stdout.reopen Jack.writer
    $stderr.reopen Jack.writer
  end

  post_fork do |captain, officer|
    Jack.writer.close
  end

  respawn_limit 15, 5

  officers 4, Jack
  # officers 2 do |officer|
  #   trap(:QUIT) { exit }
  #   trap(:TERM) { exit }
  #   # raise "HELLO"
  #   n = 0
  #   loop do
  #     Navy.logger.info "#{n} jack called (officer=#{officer.number}) pid: #{officer.officer_pid}"
  #     # Navy.logger.info "START_CTX: #{START_CTX.inspect}"
  #     # Navy.logger.info "Navy::Admiral::CAPTAINS: #{Navy::Admiral::CAPTAINS.inspect}"
  #     # Navy.logger.info "Navy::Admiral::OFFICERS: #{Navy::Captain::OFFICERS.inspect}"
  #     sleep 1
  #     n += 1
  #   end
  # end

end

captain :blackbeard do

  pid "/tmp/navy-blackbeard.pid"

  # stderr_path '/tmp/navy-blackbeard-err.log'

  officers 5 do
    trap(:QUIT) { exit }; trap(:TERM) { exit }; loop { sleep 1 }
  end
  # officers 5 do
  #   trap(:QUIT, :TRAP) { exit }

  #   nil while true
  # end

end