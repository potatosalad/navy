class Navy::Orders

  ## class_attribute :defaults ##
  def self.defaults;  nil;        end
  def self.defaults?; !!defaults; end
  def self.defaults=(val)
    singleton_class.class_eval do
      begin
        if method_defined?(:defaults) || private_method_defined?(:defaults)
          remove_method(:defaults)
        end
      rescue NameError
        # ignore this
      end
      define_method(:defaults) { val }
    end

    val
  end
  def defaults
    defined?(@defaults) ? @defaults : self.class.defaults
  end
  def defaults?
    !!defaults
  end
  attr_writer :defaults

  self.defaults = {
    timeout: 60,
    logger:  Navy.logger,
    pid:     nil
  }

  def self.inherited(base)
    base.defaults = self.defaults.dup
  end

  attr_reader :rank_class
  attr_accessor :config_file, :set

  def initialize(rank_class, options = {})
    @rank_class = rank_class
    self.set = Hash.new(:unset)
    self.config_file = options.delete(:config_file)
    @use_defaults = options.delete(:use_defaults)

    set.merge!(defaults) if @use_defaults
    options.each { |key, value| sailor_mouth.__send__(key, value) }

    reload(false)
  end

  def reload(merge_defaults = true) #:nodoc:
    if merge_defaults && @use_defaults
      set.merge!(defaults) if @use_defaults
    end
    sailor_mouth.curse!(config_file) if config_file
    # instance_eval(File.read(config_file), config_file) if config_file

    # parse_rackup_file

    # RACKUP[:set_listener] and
    #   set[:listeners] << "#{RACKUP[:host]}:#{RACKUP[:port]}"

    # # unicorn_rails creates dirs here after working_directory is bound
    # after_reload.call if after_reload

    # # working_directory binds immediately (easier error checking that way),
    # # now ensure any paths we changed are correctly set.
    # [ :pid, :stderr_path, :stdout_path ].each do |var|
    #   String === (path = set[var]) or next
    #   path = File.expand_path(path)
    #   File.writable?(path) || File.writable?(File.dirname(path)) or \
    #         raise ArgumentError, "directory for #{var}=#{path} not writable"
    # end
  end

  def give!(rank, options = {})
    only   = options[:only]   || []
    except = options[:except] || (only.empty? ? [] : set.keys - only)
    set.each do |key, value|
      value == :unset and next
      except.include?(key) and next
      rank.__send__("#{key}=", value)
    end
  end

  def sailor_mouth
    @sailor_mouth ||= rank_class::Speak.new(self)
  end

  def [](key) # :nodoc:
    set[key]
  end

end
require 'navy/speak'