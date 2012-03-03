class Navy::Rank
  def logger
    Navy.logger
  end

  private

  def proc_name(tag)
    $0 = ([
      File.basename(Navy::Admiral::START_CTX[0]),
      tag
    ]).concat(Navy::Admiral::START_CTX[:argv]).join(' ')
  end

end