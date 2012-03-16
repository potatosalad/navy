class Navy::Captain < Navy::Rank

  # This hash maps PIDs to Officers
  OFFICERS = {}
  RESPAWNS = {}

  SELF_PIPE = []

  # signal queue used for self-piping
  SIG_QUEUE = []

  # list of signals we care about and trap in admiral.
  QUEUE_SIGS = [ :WINCH, :QUIT, :INT, :TERM, :USR1, :USR2, :HUP, :TTIN, :TTOU ]

  attr_accessor :label, :captain_pid, :officer_count, :officer_job
  attr_reader   :admiral, :options

  def initialize(admiral, label, config, options = {})
    self.orig_stderr = $stderr.dup
    self.orig_stdout = $stdout.dup

    @options                = options.dup
    @options[:use_defaults] = true
    @options[:config_file]  = config
    self.orders             = Navy::Captain::Orders.new(self.class, @options)
    @options.merge!(orders.set)

    @admiral, @label = admiral, label

    orders.give!(self, except: [ :stderr_path, :stdout_path ])
  end

  def ==(other_label)
    @label == other_label
  end

  def start
    init_self_pipe!
    QUEUE_SIGS.each do |sig|
      trap(sig) do
        if $DEBUG
          logger.debug "captain[#{label}] received #{sig}"
        end
        SIG_QUEUE << sig
        awaken_captain
      end
    end
    trap(:CHLD) { awaken_captain }

    logger.info "captain[#{label}] starting"

    self.captain_pid = $$
    preload.call(self) if preload
    spawn_missing_officers
    self
  end

  def join
    respawn = true
    last_check = Time.now

    proc_name "captain[#{label}]"
    logger.info "captain[#{label}] process ready"

    begin
      reap_all_officers
      case SIG_QUEUE.shift
      when nil
        # logger.info "captain[#{label}] heartbeat"
        # avoid murdering workers after our master process (or the
        # machine) comes out of suspend/hibernation
        if (last_check + @timeout) >= (last_check = Time.now)
          heartbeat.call(self) if heartbeat
          sleep_time = murder_lazy_officers
          logger.debug("would normally murder lazy officers") if $DEBUG
        else
          sleep_time = @timeout/2.0 + 1
          logger.debug("waiting #{sleep_time}s after suspend/hibernation")
        end
        maintain_officer_count if respawn
        captain_sleep(sleep_time)
      when :QUIT # graceful shutdown
        break
      when :TERM, :INT # immediate shutdown
        stop(false)
        break
      when :USR1 # rotate logs
        logger.info "captain[#{label}] reopening logs..."
        Navy::Util.reopen_logs
        logger.info "captaion[#{label}] done reopening logs"
        kill_each_officer(:USR1)
      when :WINCH
        # if Unicorn::Configurator::RACKUP[:daemonized]
        #   respawn = false
        #   logger.info "gracefully stopping all workers"
        #   kill_each_worker(:QUIT)
        #   self.worker_processes = 0
        # else
          logger.info "SIGWINCH ignored because we're not daemonized"
        # end
      when :TTIN
        respawn = true
        self.officer_count += 1
      when :TTOU
        self.officer_count -= 1 if self.officer_count > 0
      when :HUP
        respawn = true
        # if config.config_file
          # load_config!
        # else # exec binary and exit if there's no config file
          logger.info "config_file not present, reexecuting binary"
          reexec
        # end
      end
    rescue => e
      Navy.log_error(logger, "captain[#{label}] loop error", e)
    end while true
    stop # gracefully shutdown all captains on our way out
    logger.info "captain[#{label}] complete"
  end

  # Terminates all captains, but does not exit admiral process
  def stop(graceful = true)
    before_stop.call(self, graceful) if before_stop
    limit = Time.now + patience
    until OFFICERS.empty? || (n = Time.now) > limit
      kill_each_officer(graceful ? :QUIT : :TERM)
      sleep(0.1)
      reap_all_officers
    end
    if n and n > limit
      logger.debug "captain=#{label} patience exceeded by #{n - limit} seconds (limit #{patience} seconds)" if $DEBUG
    end
    kill_each_officer(:KILL)
    after_stop.call(self, graceful) if after_stop
  end

  private

  # wait for a signal hander to wake us up and then consume the pipe
  def captain_sleep(sec)
    IO.select([ SELF_PIPE[0] ], nil, nil, sec) or return
    SELF_PIPE[0].kgio_tryread(11)
  end

  def awaken_captain
    SELF_PIPE[1].kgio_trywrite('.') # wakeup captain process from select
  end

  # reaps all unreaped officers
  def reap_all_officers
    begin
      opid, status = Process.waitpid2(-1, Process::WNOHANG)
      opid or return
      if reexec_pid == opid
        logger.error "reaped #{status.inspect} exec()-ed"
        self.reexec_pid = 0
        # self.pid = pid.chomp('.oldbin') if pid
        proc_name "captain[#{label}]"
      else
        officer = OFFICERS.delete(opid) rescue nil
        m = "reaped #{status.inspect} (#{label}) officer=#{officer.number rescue 'unknown'}"
        status.success? ? logger.info(m) : logger.error(m)
      end
    rescue Errno::ECHILD
      break
    end while true
  end

  # forcibly terminate all workers that haven't checked in in timeout seconds.  The timeout is implemented using an unlinked File
  def murder_lazy_officers
    @timeout - 1
  end

  def spawn_missing_officers
    n = -1
    until (n += 1) == @officer_count
      OFFICERS.value?(n) and next
      respawns = RESPAWNS[n]
      if respawns
        first_respawn = respawns.first
        respawn_count = respawns.size
        if respawn_count >= respawn_limit
          if (diff = Time.now - first_respawn) < respawn_limit_seconds
            logger.error "(#{label}) officer=#{n} respawn error (#{respawn_count} in #{diff} sec, limit #{respawn_limit} in #{respawn_limit_seconds} sec)"
            @officer_count -= 1
            proc_name "captain[#{label}] (error)"
            break
          else
            RESPAWNS[n] = []
          end
        end
      end
      officer = Navy::Officer.new(self, n, officer_job)
      before_fork.call(self, officer) if before_fork
      if pid = fork
        OFFICERS[pid] = officer
        RESPAWNS[n] ||= []
        RESPAWNS[n].push(Time.now)
        officer.officer_pid = pid
        post_fork.call(self, officer) if post_fork
      else
        after_fork.call(self, officer) if after_fork
        officer.start
        exit
      end
    end
    self
  rescue => e
    logger.error(e) rescue nil
    exit!
  end

  def maintain_officer_count
    (off = OFFICERS.size - @officer_count) == 0 and return
    off < 0 and return spawn_missing_officers
    OFFICERS.dup.each_pair { |opid,o|
      o.number >= @officer_count and kill_officer(:QUIT, opid) rescue nil
    }
  end

  # delivers a signal to a officer and fails gracefully if the officer
  # is no longer running.
  def kill_officer(signal, opid)
    logger.debug "captain[#{label}] sending #{signal} to #{opid}" if $DEBUG
    Process.kill(signal, opid)
  rescue Errno::ESRCH
    officer = OFFICERS.delete(opid) rescue nil
  end

  # delivers a signal to each officer
  def kill_each_officer(signal)
    OFFICERS.keys.each { |opid| kill_officer(signal, opid) }
  end

  def init_self_pipe!
    SELF_PIPE.each { |io| io.close rescue nil }
    SELF_PIPE.replace(Kgio::Pipe.new)
    SELF_PIPE.each { |io| io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }
  end

end
require 'navy/captain/orders'