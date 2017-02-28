require 'fork_break'

def breakpoint_class(klass, method_name)
  breakpoint_prepend = Module.new do
    define_method(method_name) do | *args |
      breakpoints << :"before_#{method_name}"
      result = super(*args)
      breakpoints << :"after_#{method_name}"
      return result
    end
  end
  klass.include(ForkBreak::Breakpoints)
  klass.prepend(breakpoint_prepend)
end
