
require File.dirname(__FILE__) + '/parser'
require File.dirname(__FILE__) + '/environment'
require File.dirname(__FILE__) + '/builtins'
require 'pp'

DEBUG = true


class Procedure
  # Represents a compound procedure (closure).
  #  
  # Consists of a list of arguments and body (both nested Pairs), together
  # with a link to the environment in which the procedure was defined.
  
  attr_reader :args, :body, :env
  
  def initialize(args, body, env)
    @args = args
    @body = body
    @env = env
  end
end

class SchemeInterpreter
  # A Scheme interpreter. After initialization, use the interpret() method
  # to interpret parsed Scheme expressions.
  class InterpretError < Exception; end

  include Predicates

  def initialize(output_stream=nil)
    # Initialize the interpreter. output_stream is the destination for
    # 'write' calls in the Scheme code. If nil, $stdout will be used.
    
    @global_env = _create_global_env()
    
    if output_stream.nil?
      @output_stream = $stdout
    else
      @output_stream = output_stream
    end
  end
  
  def interpret(expr)
    # Interpret the given expression in the current interpreter context 
    # and return the result of its evaluation.
    _eval(expr, @global_env)
  end
  
  def _eval(expr, env)
    if DEBUG
       puts("~~~~ Eval called on #{expr_repr(expr)} [#{expr.class}]")
    end
    
    # Standard Scheme eval (SICP 4.1.1)
    #
    if is_self_evaluating(expr)
      return expr
    elsif is_variable(expr)
      return env.lookup_var(expr.value)
    elsif is_quoted(expr)
      return text_of_quotation(expr)
    elsif is_assignment(expr)
      env.set_var_value(assignment_variable(expr).value, 
                        _eval(assignment_value(expr), env))
      return nil
    elsif is_definition(expr)
      env.define_var(definition_variable(expr).value,
                     _eval(definition_value(expr), env))
      return nil
    elsif is_if(expr)
      predicate = self._eval(if_predicate(expr), env)
      if predicate == Boolean.new(false)
        return _eval(if_alternative(expr), env)
      else
        return _eval(if_consequent(expr), env)
      end
    elsif is_cond(expr)
        return _eval(convert_cond_to_ifs(expr), env)
    elsif is_let(expr)
        return _eval(convert_let_to_application(expr), env)
    elsif is_lambda(expr)
        return Procedure.new(lambda_parameters(expr),
                             lambda_body(expr),
                             env)
    elsif is_begin(expr)
      return _eval_sequence(begin_actions(expr), env)
    elsif is_application(expr)
      puts "eval apply"
      return _apply(_eval(application_operator(expr), env),
                    _list_of_values(application_operands(expr), env))
    else
      raise InterpretError.new("Unknown expression in EVAL: #{expr}")
    end
  end
  
  def _eval_sequence(exprs, env)
    # Evaluates a sequence of expressions with _eval and returns the value
    # of the last one
    #
    first_val = _eval(first_exp(exprs), env)
    if is_last_exp(exprs)
      return first_val
    else
      return _eval_sequence(rest_exps(exprs), env)  
    end
  end  
  
  def _list_of_values(exprs, env)
    # Evaluates a list of expressions with _eval and returns a list of 
    # evaluated results.
    # The order of evaluation is left-to-right
    # 
    if has_no_operands(exprs)
      return nil
    else
      return Pair.new(_eval(first_operand(exprs), env),
                      _list_of_values(rest_operands(exprs), env))
    end
  end
  
  def _apply(proc, args)
    # Standard Scheme apply (SICP 4.1.1)
    #
    if DEBUG
      puts("~~~~ Applying procedure #{proc}")
      puts("     with args #{expr_repr(args)}")
    end
    
    if proc.instance_of?(BuiltinProcedure)
      if DEBUG
        puts("~~~~ Applying builtin procedure: #{proc.name}")
      end
      # The '' builtin gets the current output stream as a custom
      # argument
      #
      return proc.apply(expand_nested_pairs(args))  
    elsif proc.instance_of?(Procedure)
      if DEBUG
        puts("~~~~ Applying procedure with args: #{proc.args}")
        puts("     and body:\n#{expr_repr(proc.body)}")
      end
      return _eval_sequence(proc.body,
                            _extend_env_for_procedure(proc.env, 
                                                      proc.args, 
                                                      args))
    else
      raise InterpretError.new("Unknown procedure type in APPLY: #{proc}")
    end
  end
  
  def _extend_env_for_procedure(env, args, args_vals)
    # Extend an environment with bindings of args -> param_vals. 
    # Creates a new environment linked to the given env.
    # args and param_vals are Scheme lists (nested Pairs)
    #
    new_bindings = {}
    
    while ! args.nil?
      if args_vals.nil?
        raise InterpretError.new("Unassigned parameter in procedure call: #{args.first}")
      end
      new_bindings[args.first.value] = args_vals.first
      args = args.second
      args_vals = args_vals.second
    end
    
    Environment.new(new_bindings, env)
  end
  
  def _write(args)
    # Abides by the builtin procedure calling convention - args is a Ruby
    # array of arguments.
    #
    @output_stream.puts(expr_repr(args[0]))
    return nil
  end
  
  def _create_global_env()
    global_binding = {}
    $builtins_map.each do |name, func|
      global_binding[name] = BuiltinProcedure.new(name, &func)
    end
    # Add the 'write' builtin which requires access to the VM state 
    #
    global_binding['write'] = BuiltinProcedure.new('write', &lambda{|args| _write(args)})
    return Environment.new(global_binding)
  end
  
end

def interpret_code(code_str, output_stream=nil)
  # Convenience function for interpeting a string containing Scheme code.
  # Doesn't return anything, so the only visible outcome is side effects
  # from the Scheme code (such as invocations of the (write) function).
  
  parsed_exprs = SchemeParser.new.parse(code_str)    
  
  interp = SchemeInterpreter.new(output_stream)
  for expr in parsed_exprs
    interp.interpret(expr)
  end
end

def interactive_interpreter()
  # Interactive interpreter 
  
  interp = ::SchemeInterpreter.new # by default output_stream is sys.stdout
  parser = ::Parser.new
  puts("Type a Scheme expression or 'quit'")
  
  while true
    print "[ez] >> "
    inp = gets.strip
    if inp == 'quit'
      break
    end
    parsed = parser.parse(inp)
    val = interp.interpret(parsed[0])
    if val.nil?
      
    elsif val.instance_of?(Procedure)
      puts(": <procedure object>")
    else
      puts(": #{expr_repr(val)}")
    end
  end
end

#-------------------------------------------------------------------------------
if __FILE__ == $0
  interactive_interpreter
end
