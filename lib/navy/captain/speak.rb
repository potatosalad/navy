class Navy::Captain::Speak < Navy::Speak

  def officers(officer_count = 1, *args, &block)
    options = args.last.is_a?(Hash) ? args.last : {}
    orders.set[:officer_count] = officer_count
    orders.set[:officer_job]   = block_given? ? block : args[0]
    orders.set[:officer_fire_and_forget] = options[:fire_and_forget] if options.has_key?(:fire_and_forget)
  end

end