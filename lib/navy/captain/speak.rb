class Navy::Captain::Speak < Navy::Speak

  def officers(officer_count = 1, *args, &block)
    orders.set[:officer_count] = officer_count
    orders.set[:officer_job]   = block_given? ? block : args[0]
  end

end