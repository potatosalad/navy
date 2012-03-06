# cover your ears...
class Navy::Speak

  attr_reader :orders

  def initialize(orders)
    @orders = orders
  end

  def curse!(file)
    String === file and return instance_eval(File.read(file), file)
    instance_eval(&file)
  end

  ## sailor mouth ##

  def after_fork(*args, &block)
    set_hook(:after_fork, block_given? ? block : args[0])
  end

  def after_stop(*args, &block)
    set_hook(:after_stop, block_given? ? block : args[0])
  end

  def before_fork(*args, &block)
    set_hook(:before_fork, block_given? ? block : args[0])
  end

  def before_stop(*args, &block)
    set_hook(:before_stop, block_given? ? block : args[0])
  end

  def logger(obj)
    %w(debug info warn error fatal).each do |m|
      obj.respond_to?(m) and next
      raise ArgumentError, "logger=#{obj} does not respond to method=#{m}"
    end

    orders.set[:logger] = obj
  end

  def pid(path); set_path(:pid, path); end

  def post_fork(*args, &block)
    set_hook(:post_fork, block_given? ? block : args[0])
  end

  def preload(*args, &block)
    set_hook(:preload, block_given? ? block : args[0], 1)
  end

  def respawn_limit(respawns, seconds = 1.0)
    set_int(:respawn_limit, respawns, 1)
    orders.set[:respawn_limit_seconds] = seconds
  end

  def stderr_path(path)
    set_path(:stderr_path, path)
  end

  def stdout_path(path)
    set_path(:stdout_path, path)
  end

  def timeout(seconds)
    set_int(:timeout, seconds, 3)
    # POSIX says 31 days is the smallest allowed maximum timeout for select()
    max = 30 * 60 * 60 * 24
    orders.set[:timeout] = seconds > max ? max : seconds
  end

  def user(user, group = nil)
    # raises ArgumentError on invalid user/group
    Etc.getpwnam(user)
    Etc.getgrnam(group) if group
    set[:user] = [ user, group ]
  end

  def working_directory(path)
    # just let chdir raise errors
    path = File.expand_path(path)
    # if config_file &&
    #    config_file[0] != ?/ &&
    #    ! File.readable?("#{path}/#{config_file}")
    #   raise ArgumentError,
    #         "config_file=#{config_file} would not be accessible in" \
    #         " working_directory=#{path}"
    # end
    Dir.chdir(path)
    Navy::Admiral::START_CTX[:cwd] = ENV["PWD"] = path
  end

  private

  def set_int(var, n, min) #:nodoc:
    Integer === n or raise ArgumentError, "not an integer: #{var}=#{n.inspect}"
    n >= min or raise ArgumentError, "too low (< #{min}): #{var}=#{n.inspect}"
    orders.set[var] = n
  end

  def set_path(var, path) #:nodoc:
    case path
    when NilClass, String
      orders.set[var] = path
    else
      raise ArgumentError
    end
  end

  def check_bool(var, bool) # :nodoc:
    case bool
    when true, false
      return bool
    end
    raise ArgumentError, "#{var}=#{bool.inspect} not a boolean"
  end

  def set_bool(var, bool) #:nodoc:
    orders.set[var] = check_bool(var, bool)
  end

  def set_hook(var, my_proc, req_arity = 2) #:nodoc:
    case my_proc
    when Proc
      arity = my_proc.arity
      (arity == req_arity) or \
        raise ArgumentError,
              "#{var}=#{my_proc.inspect} has invalid arity: " \
              "#{arity} (need #{req_arity})"
    when NilClass
      my_proc = orders.defaults[var]
    else
      raise ArgumentError, "invalid type: #{var}=#{my_proc.inspect}"
    end
    orders.set[var] = my_proc
  end

end