$stdout.sync = $stderr.sync = true
$stdin.binmode
$stdout.binmode
$stderr.binmode

require 'navy'

module Navy::Ship

  extend self

  def launch!(options)
    $stdin.reopen("/dev/null")

    # We only start a new process group if we're not being reexecuted
    # and inheriting file descriptors from our parent
    unless ENV['NAVY_FD']
      # grandparent - reads pipe, exits when master is ready
      #  \_ parent  - exits immediately ASAP
      #      \_ unicorn master - writes to pipe when ready

      rd, wr = IO.pipe
      grandparent = $$
      if fork
        wr.close # grandparent does not write
      else
        rd.close # unicorn master does not read
        Process.setsid
        exit if fork # parent dies now
      end

      if grandparent == $$
        # this will block until HttpServer#join runs (or it dies)
        admiral_pid = (rd.readpartial(16) rescue nil).to_i
        unless admiral_pid > 1
          warn "admiral failed to start, check stderr log for details"
          exit!(1)
        end
        exit 0
      else # unicorn master process
        options[:ready_pipe] = wr
      end
    end
    # $stderr/$stderr can/will be redirected separately in the Unicorn config
    # Navy::Orders.defaults[:stderr_path]          ||= '/dev/null'
    Navy::Admiral::Orders.defaults[:stderr_path] ||= '/dev/null'
    # Navy::Captain::Orders.defaults[:stderr_path] ||= '/dev/null'
    # Navy::Orders.defaults[:stdout_path]          ||= '/dev/null'
    Navy::Admiral::Orders.defaults[:stdout_path] ||= '/dev/null'
    # Navy::Captain::Orders.defaults[:stdout_path] ||= '/dev/null'
    # cfg::SERVER[:daemonized] = true
  end

end