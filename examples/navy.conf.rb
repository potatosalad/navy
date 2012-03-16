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

# class Jacky

#   SELF_PIPE = []

#   def initialize
#     init_self_pipe!
#   end

#   def call(officer)
#     trap(:QUIT) { exit }
#     trap(:TERM) { exit }
#     # raise "HELLO"
#     n = 0
#     loop do
#       puts "#{n} jack called (officer=#{officer.number}) pid: #{officer.officer_pid}"
#       # Jack.logger.info "#{n} jack logger (officer=#{officer.number}) pid: #{officer.officer_pid}"
#       # Navy.logger.info "START_CTX: #{START_CTX.inspect}"
#       # Navy.logger.info "Navy::Admiral::CAPTAINS: #{Navy::Admiral::CAPTAINS.inspect}"
#       # Navy.logger.info "Navy::Admiral::OFFICERS: #{Navy::Captain::OFFICERS.inspect}"
#       sleep officer.number == 0 ? 0.5 : 1
#       n += 1
#     end
#   end

#   def logger
#     @logger ||= Logger.new('/tmp/jack.log')
#   end

#   private

#   def init_self_pipe!
    
#   end

# end

# module Jack

#   SELF_PIPE = []

#   extend self

#   def call(officer)
#     trap(:QUIT) { sleep 120; exit }
#     trap(:TERM) { exit }

#     # raise "HELLO"
#     n = 0
#     loop do
#       Navy.logger.info "#{n} jack called (officer=#{officer.number}) pid: #{officer.officer_pid}"
#       # Jack.logger.info "#{n} jack logger (officer=#{officer.number}) pid: #{officer.officer_pid}"
#       # Navy.logger.info "START_CTX: #{START_CTX.inspect}"
#       # Navy.logger.info "Navy::Admiral::CAPTAINS: #{Navy::Admiral::CAPTAINS.inspect}"
#       # Navy.logger.info "Navy::Admiral::OFFICERS: #{Navy::Captain::OFFICERS.inspect}"
#       sleep officer.number == 0 ? 0.5 : 1
#       n += 1
#     end
#   end

#   def logger
#     @logger ||= Logger.new('/tmp/jack.log')
#   end

#   def logger=(val)
#     @logger = val
#   end

#   def readers
#     @readers ||= {}
#   end

#   def reader=(val)
#     @reader = val
#   end

#   def writer=(val)
#     @writer = val
#   end

#   def reader
#     @reader
#   end

#   def writer
#     @writer
#   end

#   def main_reader=(val)
#     @main_reader = val
#   end

#   def main_writer=(val)
#     @main_writer = val
#   end

#   def main_reader
#     @main_reader
#   end

#   def main_writer
#     @main_writer
#   end

#   def threads
#     @threads ||= {}
#   end

#   def start
#     @thread ||= Thread.new do
#       loop do
#         IO.select([ SELF_PIPE[0] ], nil, nil, 0.1) or next
#         data = SELF_PIPE[0].gets
#         next unless data
#         data.force_encoding("BINARY") if data.respond_to?(:force_encoding)
#         pid, message = data.split(',', 2)
#         Jack.logger.info "YOUR PID WAS: #{pid}; #{message.strip}"
#         # Jack.logger.info data
#       end
#     end
#   end

#   def stop
#     if @thread
#       @thread.terminate rescue nil
#     end
#     SELF_PIPE.each { |io| io.close rescue nil }
#   end

#   # def main_thread(captain = nil)
#   #   @main_thread = nil if @main_thread and @main_thread.stop?
#   #   if @main_thread.nil?
#   #     # Jack.main_reader.close rescue nil
#   #     # Jack.main_writer.close rescue nil
#   #     Jack.main_reader, Jack.main_writer = IO.pipe
#   #     Jack.main_reader.sync = true
#   #     Jack.main_writer.sync = true
#   #   end
#   #   @main_thread ||= Thread.new do
#   #     readers = [Jack.main_reader]
#   #     loop do
#   #       rs, ws = IO.select(readers, [], [], 1)
#   #       (rs || []).each do |r|
#   #         data = r.gets
#   #         next unless data
#   #         data.force_encoding("BINARY") if data.respond_to?(:force_encoding)
#   #         ps, message = data.split(",", 2)
#   #         Jack.logger.info "pid: #{ps}, message: #{message.to_s.strip}"
#   #       end
#   #     end
#   #   end
#   # end
# end

captain :jack do

  # stderr_path "/tmp/navy-jack-err.log"
  # # stdout_path "/tmp/navy-jack-out.log"

  # preload do |captain|
  #   captain.logger.warn "captain=#{captain.label} preload"
  #   Jack::SELF_PIPE.each { |io| io.close rescue nil }
  #   # Jack::SELF_PIPE.replace(Kgio::Pipe.new)
  #   Jack::SELF_PIPE.replace(IO.pipe)
  #   Jack::SELF_PIPE.each { |io| io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC); io.sync = true }
  #   Jack.logger.info "preload"
  #   Jack.start
  # end

  # before_fork do |captain, officer|
  #   # Jack.main_thread(captain)
  #   captain.logger.warn "captain=#{captain.label} before_fork"
  #   officer.logger.warn "(#{captain.label}) officer=#{officer.number} before_fork"
  #   # if r = Jack.readers.delete(officer.number)
  #   #   r.close
  #   # end
  #   # Jack.readers[officer.number], Jack.writer = IO.pipe
  #   # Jack.reader = Jack.readers[officer.number]
  #   # Jack.reader.sync = true
  # end

  # after_fork do |captain, officer|
  #   # Jack.reader.close # we don't read
  #   # Jack.writer.sync = true
  #   captain.logger.warn "captain=#{captain.label} after_fork"
  #   officer.logger.warn "(#{captain.label}) officer=#{officer.number} after_fork"
  #   # $stdout.reopen Jack.writer
  #   # $stderr.reopen Jack.writer

  #   reader, writer = IO.pipe
  #   $stdout.reopen writer
  #   $stdout.reopen writer

  #   Thread.new do
  #     until reader.eof?
  #       Jack::SELF_PIPE[1].puts "%s,%s" % [ officer.officer_pid, reader.gets ]
  #     end
  #   end
  # end

  # after_stop do |captain, graceful|
  #   Jack.stop if graceful
  # end

  # post_fork do |captain, officer|
  #   # Jack.writer.close # we don't write
  #   # if t = Jack.threads[officer.number]
  #   #   t.terminate unless t.stop?
  #   # else
  #   #   Jack.threads[officer.number] = Thread.new do
  #   #     reader = Jack.reader
  #   #     until reader.eof?
  #   #       Jack::SELF_PIPE[1].puts "%s,%s" % [ officer.officer_pid, reader.gets ]
  #   #     end
  #   #   end
  #   # end
  #   # Jack.reader.lcose
  #   # Thread.new do
  #   #   # Jack.main_reader.close
  #   #   # Jack.main_writer.close
  #   #   loop do
  #   #     rs, ws = IO.select([Jack.reader], [], [], 1)
  #   #     (rs || []).each do |r|
  #   #       data = r.gets
  #   #       next unless data
  #   #       data.force_encoding("BINARY") if data.respond_to?(:force_encoding)
  #   #       # ps, message = data.split(",", 2)
  #   #       # color = colors[ps.split(".").first]
  #   #       # info message, ps, color
  #   #       # Jack.mutex.synchronize do
  #   #       # Jack.logger.info "pid: #{ps}, message: #{message}"
  #   #       # Jack.logger.info data.strip
  #   #       # end
  #   #       Jack.main_writer.puts "pidpidpid: #{officer.officer_pid}, message: #{data}"
  #   #     end
  #   #   end
  #   # end
  #   # Thread.new do
  #   #   reader, writer = Jack.reader, Jack.writer
  #   #   loop do
  #   #     rs, ws = IO.select([reader], [], [], 1)
  #   #     (rs || []).each do |r|
  #   #       data = r.gets
  #   #       next unless data
  #   #       data.force_encoding("BINARY") if data.respond_to?(:force_encoding)
  #   #       # ps, message = data.split(",", 2)
  #   #       # color = colors[ps.split(".").first]
  #   #       # info message, ps, color
  #   #       # Jack.mutex.synchronize do
  #   #       # Jack.logger.info "pid: #{ps}, message: #{message}"
  #   #       writer.write "%s,%s" [ '13', data ]
  #   #       # end
  #   #     end
  #   #   end
  #   # end
  # end

  # preload do |captain|
  #   require 'fileutils'
  #   require 'rainbow'
  #   Sickill::Rainbow.enabled = true
  # end

  respawn_limit 15, 5

  patience 5

  # heartbeat do |captain|
  #   captain.logger.info "captain=#{captain.label} heartbeat".color(:red)
  #   captain.class::OFFICERS.each do |officer_pid, officer|
  #     # begin
  #       name = "/tmp/ps#{officer_pid}"
  #       system("ps -o rss= -p #{officer_pid} > #{name}")
  #       mem_usage = (::File.read(name) rescue 0).to_s.strip.to_i
  #       ::FileUtils.rm_f(name)

  #       if mem_usage > 2000
  #         captain.send(:kill_officer, :TERM, officer_pid)
  #         captain.logger.info "captain=#{captain.label} officer=#{officer.number} over memory limit, sending TERM (pid: #{officer_pid}, mem: #{mem_usage} KB)".color(:yellow)
  #       else

  #       # mem_usage = `ps -o rss= -p #{officer_pid}`.to_s.strip
  #       # mem_usage = 20
  #       captain.logger.info "captain=#{captain.label} checking officer=#{officer.number} (pid: #{officer_pid}, mem: #{mem_usage} KB)".color(:green)
  #     # rescue => e
  #       # captain.logger.error "captain=#{captain.label} checking officer=#{officer.number} (pid: #{pid}) error: #{e.inspect}".color(:red)
  #     end
  #   end
  # end

  officers 4 do |officer|
    trap(:QUIT) { sleep 120; exit }
    trap(:TERM) { exit }

    # raise "HELLO"
    n = 0
    loop do
      Navy.logger.info "#{n} jack called (officer=#{officer.number}) pid: #{officer.officer_pid}"
      # Jack.logger.info "#{n} jack logger (officer=#{officer.number}) pid: #{officer.officer_pid}"
      # Navy.logger.info "START_CTX: #{START_CTX.inspect}"
      # Navy.logger.info "Navy::Admiral::CAPTAINS: #{Navy::Admiral::CAPTAINS.inspect}"
      # Navy.logger.info "Navy::Admiral::OFFICERS: #{Navy::Captain::OFFICERS.inspect}"
      sleep officer.number == 0 ? 0.5 : 1
      n += 1
    end
  end
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