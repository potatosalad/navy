class Navy::Captain < Navy::Rank

  # This hash maps PIDs to Officers
  OFFICERS = {}

  SELF_PIPE = []

  # signal queue used for self-piping
  SIG_QUEUE = []

  # list of signals we care about and trap in admiral.
  QUEUE_SIGS = [ :WINCH, :QUIT, :INT, :TERM, :USR1, :USR2, :HUP, :TTIN, :TTOU ]

  attr_accessor :label, :captain_pid, :timeout, :reexec_pid, :number
  attr_reader :admiral, :options

  def initialize(admiral, label, options = {})
    @admiral, @options = admiral, options.dup
    @label = label
    @number = 1
    @timeout = 15
  end

  def ==(other_label)
    @label == other_label
  end

  def start
    init_self_pipe!
    QUEUE_SIGS.each { |sig| trap(sig) { SIG_QUEUE << sig; awaken_captain } }
    trap(:CHLD) { awaken_captain }

    logger.info "captain[#{label}] starting"

    self.captain_pid = $$
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
        # avoid murdering workers after our master process (or the
        # machine) comes out of suspend/hibernation
        if (last_check + @timeout) >= (last_check = Time.now)
          # sleep_time = murder_lazy_workers
          logger.debug("would normally murder lazy officers")
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
        # Unicorn::Util.reopen_logs
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
        self.number += 1
      when :TTOU
        self.number -= 1 if self.number > 0
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
    limit = Time.now + timeout
    until OFFICERS.empty? || Time.now > limit
      kill_each_officer(graceful ? :QUIT : :TERM)
      sleep(0.1)
      reap_all_officers
    end
    kill_each_officer(:KILL)
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
        m = "reaped #{status.inspect} officer=#{officer.number rescue 'unknown'}"
        status.success? ? logger.info(m) : logger.error(m)
      end
    rescue Errno::ECHILD
      break
    end while true
  end

  def spawn_missing_officers
    n = -1
    until (n += 1) == @number
      OFFICERS.value?(n) and next
      officer = Navy::Officer.new(self, n, options[:job])
      if pid = fork
        OFFICERS[pid] = officer
      else
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
    (off = OFFICERS.size - @number) == 0 and return
    off < 0 and return spawn_missing_officers
    OFFICERS.dup.each_pair { |opid,o|
      o.number >= @number and kill_officer(:QUIT, opid) rescue nil
    }
  end

  # delivers a signal to a worker and fails gracefully if the worker
  # is no longer running.
  def kill_officer(signal, opid)
    logger.warn "captain[#{label}] sending #{signal} to #{opid}"
    Process.kill(signal, opid)
  rescue Errno::ESRCH
    officer = OFFICERS.delete(opid) rescue nil
  end

  # delivers a signal to each worker
  def kill_each_officer(signal)
    OFFICERS.keys.each { |wpid| kill_officer(signal, wpid) }
  end

  def init_self_pipe!
    SELF_PIPE.each { |io| io.close rescue nil }
    SELF_PIPE.replace(Kgio::Pipe.new)
    SELF_PIPE.each { |io| io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }
  end

end