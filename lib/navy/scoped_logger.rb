class Navy::ScopedLogger

  attr_accessor :logger, :scope

  def initialize(logger, scope = nil)
    @logger, @scope = logger, scope
  end

  def add(*args, &block)
    scoped(:add, *args, &block)
  end

  def debug(*args, &block)
    scoped(:debug, *args, &block)
  end

  def info(*args, &block)
    scoped(:info, *args, &block)
  end

  def warn(*args, &block)
    scoped(:warn, *args, &block)
  end

  def error(*args, &block)
    scoped(:error, *args, &block)
  end

  def fatal(*args, &block)
    scoped(:fatal, *args, &block)
  end

  def respond_to?(*args)
    @logger.respond_to?(*args)
  end

  protected

  def method_missing(name, *args, &block)
    @logger.__send__(name, *args, &block)
  end

  def scoped(name, *args, &block)
    start_scope!
    retval = @logger.__send__(name, *args, &block)
    stop_scope!
    return retval
  end

  def start_scope!
    return unless scope
    scope.current_stdout = $stdout.dup
    scope.current_stderr = $stderr.dup
    if scope.stderr_path
      scope.stderr_path = scope.stderr_path
    else
      $stderr.reopen scope.orig_stderr
    end
    if scope.stdout_path
      scope.stdout_path = scope.stdout_path
    else
      $stdout.reopen scope.orig_stdout
    end
  end

  def stop_scope!
    return unless scope
    return unless scope.current_stderr and scope.current_stdout
    $stdout.reopen scope.current_stdout
    $stderr.reopen scope.current_stderr
    scope.current_stderr = scope.current_stdout = nil
  end

end