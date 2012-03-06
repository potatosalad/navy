class Navy::Admiral < Navy::Rank

  # This hash maps PIDs to Captains
  CAPTAINS = {}
  RESPAWNS = {}

  SELF_PIPE = []

  # signal queue used for self-piping
  SIG_QUEUE = []

  # list of signals we care about and trap in admiral.
  QUEUE_SIGS = [ :WINCH, :QUIT, :INT, :TERM, :USR1, :USR2, :HUP, :TTIN, :TTOU ]

  START_CTX = {
    :argv => ARGV.map { |arg| arg.dup },
    0 => $0.dup,
  }
  # We favor ENV['PWD'] since it is (usually) symlink aware for Capistrano
  # and like systems
  START_CTX[:cwd] = begin
    a = File.stat(pwd = ENV['PWD'])
    b = File.stat(Dir.pwd)
    a.ino == b.ino && a.dev == b.dev ? pwd : Dir.pwd
  rescue
    Dir.pwd
  end

  attr_accessor :admiral_pid, :captains, :timeout, :respawn_limit, :respawn_limit_seconds
  attr_reader :options

  def initialize(options = {})
    self.orig_stderr = $stderr.dup
    self.orig_stdout = $stdout.dup
    self.reexec_pid = 0

    @options                = options.dup
    @ready_pipe             = @options.delete(:ready_pipe)
    @options[:use_defaults] = true
    self.orders             = Navy::Admiral::Orders.new(self.class, @options)

    orders.give!(self, except: [ :stderr_path, :stdout_path ])
  end

  def start
    orders.give!(self, only: [ :stderr_path, :stdout_path ])
    init_self_pipe!
    QUEUE_SIGS.each do |sig|
      trap(sig) do
        logger.debug "admiral received #{sig}" if $DEBUG
        SIG_QUEUE << sig
        awaken_admiral
      end
    end
    trap(:CHLD) { awaken_admiral }

    logger.info "admiral starting"

    self.admiral_pid = $$
    preload.call(self) if preload
    spawn_missing_captains
    self
  end

  def join
    respawn = true
    last_check = Time.now

    proc_name 'admiral'
    logger.info "admiral process ready"
    if @ready_pipe
      @ready_pipe.syswrite($$.to_s)
      @ready_pipe = @ready_pipe.close rescue nil
    end
    begin
      reap_all_captains
      case SIG_QUEUE.shift
      when nil
        # avoid murdering workers after our master process (or the
        # machine) comes out of suspend/hibernation
        if (last_check + @timeout) >= (last_check = Time.now)
          sleep_time = murder_lazy_captains
          logger.debug("would normally murder lazy captains") if $DEBUG
        else
          sleep_time = @timeout/2.0 + 1
          logger.debug("waiting #{sleep_time}s after suspend/hibernation")
        end
        maintain_captain_count if respawn
        admiral_sleep(sleep_time)
      when :QUIT # graceful shutdown
        break
      when :TERM, :INT # immediate shutdown
        stop(false)
        break
      when :USR1 # rotate logs
        logger.info "admiral reopening logs..."
        Navy::Util.reopen_logs
        logger.info "admiral done reopening logs"
        kill_each_captain(:USR1)
      when :USR2 # exec binary, stay alive in case something went wrong
        reexec
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
        kill_each_captain(:TTIN)
      when :TTOU
        kill_each_captain(:TTOU)
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
      Navy.log_error(logger, "admiral loop error", e)
    end while true
    stop # gracefully shutdown all captains on our way out
    logger.info "admiral complete"
  end

  # Terminates all captains, but does not exit admiral process
  def stop(graceful = true)
    limit = Time.now + timeout
    until CAPTAINS.empty? || Time.now > limit
      kill_each_captain(graceful ? :QUIT : :TERM)
      sleep(0.1)
      reap_all_captains
    end
    kill_each_captain(:KILL)
  end

  private

  # wait for a signal hander to wake us up and then consume the pipe
  def admiral_sleep(sec)
    IO.select([ SELF_PIPE[0] ], nil, nil, sec) or return
    SELF_PIPE[0].kgio_tryread(11)
  end

  def awaken_admiral
    SELF_PIPE[1].kgio_trywrite('.') # wakeup admiral process from select
  end

  # reaps all unreaped captains
  def reap_all_captains
    begin
      cpid, status = Process.waitpid2(-1, Process::WNOHANG)
      cpid or return
      if reexec_pid == cpid
        logger.error "reaped #{status.inspect} exec()-ed"
        self.reexec_pid = 0
        self.pid = pid.chomp('.oldbin') if pid
        proc_name "admiral"
      else
        captain = CAPTAINS.delete(cpid) rescue nil
        m = "reaped #{status.inspect} captain=#{captain.label rescue 'unknown'}"
        status.success? ? logger.info(m) : logger.error(m)
      end
    rescue Errno::ECHILD
      break
    end while true
  end

  # forcibly terminate all workers that haven't checked in in timeout seconds.  The timeout is implemented using an unlinked File
  def murder_lazy_captains
    @timeout - 1
  end

  # reexecutes the START_CTX with a new binary
  def reexec
    if reexec_pid > 0
      begin
        Process.kill(0, reexec_pid)
        logger.error "reexec-ed child already running PID:#{reexec_pid}"
        return
      rescue Errno::ESRCH
        self.reexec_pid = 0
      end
    end

    if pid
      old_pid = "#{pid}.oldbin"
      begin
        self.pid = old_pid  # clear the path for a new pid file
      rescue ArgumentError
        logger.error "old PID:#{valid_pid?(old_pid)} running with " \
                     "existing pid=#{old_pid}, refusing rexec"
        return
      rescue => e
        logger.error "error writing pid=#{old_pid} #{e.class} #{e.message}"
        return
      end
    end

    logger.info "reexec admiral"

    self.reexec_pid = fork do
      # ENV['NAVY_FD'] = listener_fds.keys.join(',')
      ENV['NAVY_FD'] = '1'
      Dir.chdir(START_CTX[:cwd])
      cmd = [ START_CTX[0] ].concat(START_CTX[:argv])

      # exec(command, hash) works in at least 1.9.1+, but will only be
      # required in 1.9.4/2.0.0 at earliest.
      logger.info "executing #{cmd.inspect} (in #{Dir.pwd})"
      before_exec.call(self)
      exec(*cmd)
    end
    proc_name 'admiral (old)'
  end

  def spawn_missing_captains
    captains.each do |label, config|
      CAPTAINS.value?(label) and next
      respawns = RESPAWNS[label]
      if respawns
        first_respawn = respawns.first
        respawn_count = respawns.size
        if respawn_count >= respawn_limit
          if (diff = Time.now - first_respawn) < respawn_limit_seconds
            logger.error "captain=#{label} respawn error (#{respawn_count} in #{diff} sec, limit #{respawn_limit} in #{respawn_limit_seconds} sec)"
            @errored_captains ||= {}
            @errored_captains[label] = captains.delete(label)
            proc_name "admiral (error)"
            break
          else
            RESPAWNS[label] = []
          end
        end
      end
      captain = Navy::Captain.new(self, label, config)
      before_fork.call(self, captain) if before_fork
      if pid = fork
        CAPTAINS[pid] = captain
        RESPAWNS[label] ||= []
        RESPAWNS[label].push(Time.now)
        captain.captain_pid = pid
        post_fork.call(self, captain) if post_fork
      else
        captain.orders.give!(captain, only: [ :stderr_path, :stdout_path ])
        after_fork.call(self, captain) if after_fork
        captain.start.join
        exit
      end
    end
    self
  rescue => e
    logger.error(e) rescue nil
    exit!
  end

  def maintain_captain_count
    (off = CAPTAINS.size - captains.size) == 0 and return
    off < 0 and return spawn_missing_captains
    CAPTAINS.dup.each_pair { |cpid,c|
      captains.key?(c.label) or kill_captain(:QUIT, cpid) rescue nil
    }
  end

  # delivers a signal to a captain and fails gracefully if the captain
  # is no longer running.
  def kill_captain(signal, cpid)
    logger.debug "admiral sending #{signal} to #{cpid}" if $DEBUG
    Process.kill(signal, cpid)
  rescue Errno::ESRCH
    captain = CAPTAINS.delete(cpid) rescue nil
  end

  # delivers a signal to each captain
  def kill_each_captain(signal)
    CAPTAINS.keys.each { |cpid| kill_captain(signal, cpid) }
  end

  def init_self_pipe!
    SELF_PIPE.each { |io| io.close rescue nil }
    SELF_PIPE.replace(Kgio::Pipe.new)
    SELF_PIPE.each { |io| io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC) }
  end

end
require 'navy/admiral/orders'