class Navy::Officer < Navy::Rank
  attr_accessor :number
  attr_reader :captain, :job
  def initialize(captain, number, job)
    @captain, @number, @job = captain, number, job
  end

  def ==(other_number)
    @number == other_number
  end

  def start
    proc_name "(#{captain.label}) officer[#{number}]"
    job.call
  rescue => e
    logger.error(e) rescue nil
    exit!
  end
end