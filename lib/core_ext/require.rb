Kernel.module_eval do
  def require_with_logging(name)
    $stderr.write "* require #{name}\n"
    require_without_logging(name)
  end

  alias_method :require_without_logging, :require
  alias_method :require, :require_with_logging
end
