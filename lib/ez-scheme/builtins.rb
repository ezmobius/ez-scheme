require File.dirname(__FILE__) + '/expr'

include Predicates

class BuiltinProcedure
  # A lightweight representation of builtin procedures, parallel to the
  # approach taken in SICP.
  #
  # The calling convention for builtin procedures is as follows:
  #
  # Arguments are passed in as a Ruby array. Each argument is a Scheme
  # expression (from the expr module). The procedure should always return
  # a single value which is also a Scheme expression.
  attr_accessor :name, :proc
  
  def initialize(name, &proc)
    @name = name
    @proc = proc
  end
  
  def apply(args)
    @proc.call(args)
  end
end

class BuiltinError < Exception; end


def builtin_pair_p(args)
  Boolean.new(args[0].instance_of?(Pair))
end

def builtin_boolean_p(args)
  Boolean.new(args[0].instance_of?(Boolean))
end

def builtin_symbol_p(args)
  Boolean.new(args[0].instance_of?(Sym))
end

def builtin_number_p(args)
  Boolean.new(args[0].instance_of?(Number))
end

def builtin_zero_p(args)
  Boolean.new(args[0].instance_of?(Number) && (args[0].value == 0))
end

def builtin_null_p(args)
  Boolean.new(args[0].nil?)
end

def builtin_cons(args)
  Pair.new(args[0], args[1])
end

def builtin_list(args)
  make_nested_pairs(*args)
end

def builtin_car(args)
  args[0].first
end

def builtin_set_car(args)
  args[0].first = args[1]
  return nil
end

def builtin_set_cdr(args)
  args[0].second = args[1]
  return nil
end

def builtin_cdr(args)
  args[0].second
end

def builtin_cadr(args)
  args[0].second.first
end

def builtin_caddr(args)
  args[0].second.second.first
end

def builtin_eqv(args)
  # A rough approximation of Scheme's eqv? that's good enough for most
  # practical purposes
  #
  left, right = args[0], args[1]
  
  if left.instance_of?(Pair) and right.instance_of?(Pair)
    Boolean.new(left.object_id == right.object_id)
  else
    Boolean.new(left == right)
  end
end

def builtin_not(args)
  if args[0].instance_of?(Boolean) and args[0].value == false
    Boolean.new(true)
  else
    Boolean.new(false)
  end
end
# The 'and' and 'or' builtins are conforming to the definition in 
# R5RS, section 4.2
#
def builtin_and(args)
  for v in args
    if v == Boolean.new(false)
      return v
    end
  end
  if args.size > 0
    args[-1]
  else
    Boolean.new(true)
  end
end

def builtin_or(args)
  for v in args
    if v == Boolean.new(true)
      return v
    end
  end
  if args.size > 0
    args[-1]
  else
    Boolean.new(false)
  end
end

def make_comparison_operator_builtin(op)
    Proc.new{ |args|
      a = args[0]
      res = nil
      for b in args[1..-1]
        if a.value.send(op, b.value)
          a = b
        else
          break res = Boolean.new(false)
        end
      end
      if res
        res
      else
        Boolean.new(true)
      end
    }
end

def make_arith_operator_builtin(op)
  lambda{ |args| Number.new(args.map{|a| a.value}.inject(op)) }
end

def eval_ruby_code
  lambda{|args| Sstring.new(eval(args[0]).to_s)}
end
    
$builtins_map = {
    'eqv?' =>           lambda{ |args| builtin_eqv(args) },
    'eq?' =>            lambda{ |args| builtin_eqv(args) },
    'pair?' =>          lambda{ |args| builtin_pair_p(args) },
    'zero?' =>          lambda{ |args| builtin_zero_p(args) },
    'boolean?' =>       lambda{ |args| builtin_boolean_p(args) },
    'symbol?' =>        lambda{ |args| builtin_symbol_p(args) },
    'number?' =>        lambda{ |args| builtin_number_p(args) },
    'null?'   =>        lambda{ |args| builtin_null_p(args) },
    'cons' =>           lambda{ |args| builtin_cons(args) },
    'list'  =>          lambda{ |args| builtin_list(args) },
    'car'  =>           lambda{ |args| builtin_car(args) },
    'cdr'  =>           lambda{ |args| builtin_cdr(args) },
    'cadr'  =>          lambda{ |args| builtin_cadr(args) },
    'caddr'  =>         lambda{ |args| builtin_caddr(args) },
    'set-car!'  =>      lambda{ |args| builtin_set_car(args) },
    'set-cdr!'  =>      lambda{ |args| builtin_set_cdr(args) },
    'not'  =>           lambda{ |args| builtin_not(args) },
    'and'  =>           lambda{ |args| builtin_and(args) },
    'or'  =>            lambda{ |args| builtin_or(args) },
    '+'  =>             make_arith_operator_builtin(:+),
    '-'  =>             make_arith_operator_builtin(:-),
    '*'  =>             make_arith_operator_builtin(:*),
    'quotient' =>       make_arith_operator_builtin(:/),
    'modulo'  =>        make_arith_operator_builtin(:%),
    '='  =>             make_comparison_operator_builtin(:==),
    '>='  =>            make_comparison_operator_builtin(:>=),
    '<='  =>            make_comparison_operator_builtin(:<=),
    '>'  =>             make_comparison_operator_builtin(:>),
    '<'  =>             make_comparison_operator_builtin(:<),
    'rb'  =>            eval_ruby_code
}
