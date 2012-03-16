class Navy::Rank

  # orders are configuration settings
  attr_accessor :orders

  ## callbacks ##
  attr_accessor :before_fork,
                :before_stop,
                :after_fork,
                :after_stop,
                :heartbeat,
                :post_fork

  ## reexec ##
  attr_accessor :reexec_pid

  ## respawn ##
  attr_accessor :respawn_limit, :respawn_limit_seconds

  ## stderr/stdout ##
  attr_reader   :stdout_path, :stderr_path
  attr_accessor :orig_stdout, :orig_stderr, :current_stdout, :current_stderr

  ## timeouts ##
  attr_accessor :patience, :timeout

  def logger
    (@logger ||= orders[:logger]).tap do |log|
      log.scope = self #if log.respond_to?(:scope=)
    end
  end
  attr_writer :logger

  attr_reader :options

  # sets the path for the PID file of the master process
  def pid=(path)
    if path
      if x = valid_pid?(path)
        return path if pid && path == pid && x == $$
        if x == reexec_pid && pid =~ /\.oldbin\z/
          logger.warn("will not set pid=#{path} while reexec-ed "\
                      "child is running PID:#{x}")
          return
        end
        raise ArgumentError, "Already running on PID:#{x} " \
                             "(or pid=#{path} is stale)"
      end
    end
    unlink_pid_safe(pid) if pid

    if path
      fp = begin
        tmp = "#{File.dirname(path)}/#{rand}.#$$"
        File.open(tmp, File::RDWR|File::CREAT|File::EXCL, 0644)
      rescue Errno::EEXIST
        retry
      end
      fp.syswrite("#$$\n")
      File.rename(fp.path, path)
      fp.close
    end
    @pid = path
  end
  attr_reader :pid

  attr_accessor :preload

  def stdout_path=(path)
    @stdout_path = path
    redirect_io($stdout, path)
  end
  def stderr_path=(path)
    @stderr_path = path
    redirect_io($stderr, path)
  end

  private

  # unlinks a PID file at given +path+ if it contains the current PID
  # still potentially racy without locking the directory (which is
  # non-portable and may interact badly with other programs), but the
  # window for hitting the race condition is small
  def unlink_pid_safe(path)
    (File.read(path).to_i == $$ and File.unlink(path)) rescue nil
  end

  # returns a PID if a given path contains a non-stale PID file,
  # nil otherwise.
  def valid_pid?(path)
    wpid = File.read(path).to_i
    wpid <= 0 and return
    Process.kill(0, wpid)
    wpid
  rescue Errno::ESRCH, Errno::ENOENT, Errno::EPERM
    # don't unlink stale pid files, racy without non-portable locking...
  end

  def proc_name(tag)
    $0 = ([
      File.basename(Navy::Admiral::START_CTX[0]),
      tag
    ]).concat(Navy::Admiral::START_CTX[:argv]).join(' ')
  end

  def redirect_io(io, path)
    File.open(path, 'ab') { |fp| io.reopen(fp) } if path
    io.sync = true
  end

end