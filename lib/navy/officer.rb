class Navy::Officer < Navy::Rank
  attr_accessor :number, :officer_pid
  attr_reader :captain, :job
  def initialize(captain, number, job)
    @captain, @number, @job = captain, number, job
  end

  def ==(other_number)
    @number == other_number
  end

  def logger
    captain.logger
  end

  def start
    self.officer_pid = $$
    proc_name "(#{captain.label}) officer[#{number}]"
    (job.respond_to?(:arity) && job.arity == 0) ? job.call : job.call(self)
  rescue => e
    logger.error(e) rescue nil
    exit!
  end
end