class Navy::Admiral::Speak < Navy::Speak

  def before_exec(*args, &block)
    set_hook(:before_exec, block_given? ? block : args[0], 1)
  end

  def captain(label, *args, &block)
    orders.set[:captains] ||= {}
    orders.set[:captains][label] = block_given? ? block : args[0]
  end

end