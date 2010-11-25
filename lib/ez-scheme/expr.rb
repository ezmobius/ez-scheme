
class Pair
  
  attr_accessor :first, :second
  def initialize(first, second)
    @first, @second = first, second
  end
  
  def ==(other)
    if Pair === other
      !!((@first == other.first) && (@second == other.second))
    else
      false
    end
  end
  
end

class Number
  
  attr_reader :value
  
  def initialize(value)
    @value = value
  end
  
  def to_s
    @value.to_s
  end
  
  def ==(other)
    if Number === other
      @value == other.value
    else
      @value == other
    end
  end
  
end

class Sym
  
  attr_reader :value
  
  def initialize(value)
    @value = value
  end
  
  def to_s
    @value.to_s
  end
  
  def ==(other)
    if Sym === other
      @value == other.value
    else
      @value == other
    end
  end
  
end

class Sstring
  
  attr_reader :value
  
  def initialize(value)
    @value = value.gsub('"', '')
  end
  
  def to_s
    @value.to_s
  end
  
  def to_str
    @value.to_str
  end
  
  def ==(other)
    if Sym === other
      @value == other.value
    else
      @value == other
    end
  end
  
end

class Boolean
  
  attr_reader :value
  
  def initialize(value)
    @value = value
  end
  
  def to_s
    if @value
      '#t'
    else
      '#f'
    end
  end
  
  def ==(other)
    if Boolean === other
      @value == other.value
    else
      @value == other
    end
  end
  
end

class ExprError < Exception; end

module Predicates

  # A textual representation of the given Scheme expression.
  def repr_rec(obj)
    if obj.nil?
      return '()'
    elsif [Boolean, Sym, Number, Sstring].any? { |c| obj.instance_of?(c) }
      return obj.to_s
    elsif obj.instance_of?(Pair) 
      str = '(' + repr_rec(obj.first)
      while obj.second.instance_of?(Pair) 
        str += (' ' + repr_rec(obj.second.first))
        obj = obj.second
      end
      if obj.second.nil?
        str += ')'
      else
        str += (' . ' + repr_rec(obj.second) + ')')
      end
      return str
    elsif obj.instance_of?(Array)
      obj.map {|o| repr_rec(o) }.join("\n")
    else
      obj.class.to_s
      #raise ExprError.new("Unexpected type: #{obj.class}")
    end
  end
  
  def expr_repr(expr)
    return repr_rec(expr)
  end
  
  # Given a list of arguments, creates a list in Scheme representation 
  # (nested Pairs)
  def make_nested_pairs(*args)
    if args.size == 0
      return nil
    end
    Pair.new(args[0], make_nested_pairs(*args[1..-1]))
  end
  
  # Given a list in Scheme representation (nested Pairs), expands it into
  # a Ruby list.
  # 
  # When recursive=True, expands nested pairs as well. I.e Scheme's 
  # (1 (2 3) 4) is correctly translated to [1, [2, 3], 4]). 
  # Ignores dotted-pair endings: (1 2 . 3) will be translated to [1, 2]
  
  def expand_nested_pairs(pair, recursive=false)
    lst = []
    while pair.instance_of?(Pair)
      head = pair.first
      if recursive and head.instance_of?(Pair)
        lst << expand_nested_pairs(head)
      else
        lst << head
      end
      pair = pair.second
    end
    lst
  end
  
  # Check if the given expression is a Scheme expression.
  def is_scheme_expr(exp)
    exp.nil? or is_self_evaluating(exp) or is_variable(exp) or exp.instance_of?(Pair)
  end
  
  #
  # Dissection of Scheme expressions into their constituents. Roughly follows 
  # section 4.1.2 of SICP.
  #
  def is_self_evaluating(exp)
    [Number, Boolean, Sstring].any?{|c| exp.instance_of?(c)}
  end
  
  def is_variable(exp)
    exp.instance_of?(Sym)
  end
  
  # Is the expression a list starting with the given symbolic tag?
  def is_tagged_list(exp, tag)
    exp.instance_of?(Pair) and exp.first == tag
  end
  
  def is_quoted(exp)
    is_tagged_list(exp, 'quote')
  end
  
  def text_of_quotation(exp)
    exp.second.first
  end
  
  def is_assignment(exp)
    is_tagged_list(exp, 'set!')
  end
  
  def assignment_variable(exp)
    exp.second.first
  end
  
  def assignment_value(exp)
    exp.second.second.first
  end
  
  #
  # Definitions have the form
  #   (define <var> <value>)
  # or the form
  #   (define (<var> <parameter1> ... <parametern>)
  #     <body>)
  #
  # The latter form (standard procedure definition) is syntactic sugar for
  #
  #   (define <var>
  #     (lambda (<parameter1> ... <parametern>)
  #       <body>))
  #
  def is_definition(exp)
    is_tagged_list(exp, 'define')
  end
  
  def definition_variable(exp)
    if exp.second.first.instance_of?(Sym)
      exp.second.first
    else
      exp.second.first.first
    end
  end
  
  def definition_value(exp)
    if exp.second.first.instance_of?(Sym)
      exp.second.second.first
    else
      make_lambda(exp.second.first.second,    # formal parameters
                  exp.second.second)          # body
    end
  end
  
  def is_lambda(exp)
    is_tagged_list(exp, 'lambda')
  end
  
  def lambda_parameters(exp)
    exp.second.first
  end
  
  def lambda_body(exp)
    exp.second.second
  end
  
  def make_lambda(parameters, body)
    Pair.new(Sym.new('lambda'), Pair.new(parameters, body))
  end
  
  def is_if(exp)
    is_tagged_list(exp, 'if')
  end
  
  def if_predicate(exp)
    exp.second.first
  end
  
  def if_consequent(exp)
    exp.second.second.first
  end
  
  def if_alternative(exp)
    alter_exp = exp.second.second.second
    if alter_exp.nil?
      Boolean.new(false)
    else
      alter_exp.first
    end
  end
    
  def make_if(predicate, consequent, alternative)
    make_nested_pairs(Sym.new('if'), predicate, consequent, alternative)
  end
  
  def is_begin(exp)
    is_tagged_list(exp, 'begin')
  end
  
  def begin_actions(exp)
    exp.second
  end
  
  def is_last_exp(seq)
    seq.second.nil?
  end
  
  def first_exp(seq)
    seq.first
  end
  
  def rest_exps(seq)
    seq.second
  end
  
  #
  # Procedure applications
  #
  def is_application(exp)
    exp.instance_of?(Pair)
  end
  
  def application_operator(exp)
    exp.first
  end
  
  def application_operands(exp)
    exp.second
  end
  
  def has_no_operands(ops)
    ops.nil?
  end
  
  def first_operand(ops)
    ops.first
  end
  
  def rest_operands(ops)
    ops.second
  end
  
  # Convert a sequence of expressions to a single expression, adding 'begin
  # if required.
  def sequence_to_exp(seq)
    if seq.nil?
      return nil
    elsif is_last_exp(seq)
      return first_exp(seq)
    else
      return Pair.new(Sym.new('begin'), seq)
    end
  end
  
  #
  # 'cond' is a derived expression and is expanded into a series of nested 'if's.
  #
  def is_cond(exp)
    is_tagged_list(exp, 'cond')
  end
  
  def cond_clauses(exp)
    exp.second
  end
  
  def cond_predicate(clause)
    clause.first
  end
  
  def cond_actions(clause)
    clause.second
  end
  
  def is_cond_else_clause(clause)
    cond_predicate(clause) == Sym.new('else')
  end
  
  def convert_cond_to_ifs(exp)
    expand_cond_clauses(cond_clauses(exp))
  end
  
  def expand_cond_clauses(clauses)
    if clauses.nil?
      return Boolean.new(false)
    end
    first = clauses.first
    rest = clauses.second
    if is_cond_else_clause(first)
      if rest.nil?
        return sequence_to_exp(cond_actions(first))
      else
        raise ExprError.new("ELSE clause is not last: #{expr_repr(clauses)}")
      end
    else
      make_if(cond_predicate(first), 
              sequence_to_exp(cond_actions(first)),
              expand_cond_clauses(rest))
    end
  end
    
  
  #
  # 'let' is a derived expression:
  #
  # (let ((var1 exp1) ... (varN expN))
  #     body)
  #
  # is expanded to:
  #
  # ((lambda (var1 ... varN)
  #     body)
  #   exp1
  #   ...
  #   expN)
  #
  def is_let(exp)
    is_tagged_list(exp, 'let')
  end
  
  def let_bindings(exp)
    exp.second.first
  end
  
  def let_body(exp)
    exp.second.second
  end
  
  # Given a Scheme 'let' expression converts it to the appropriate 
  # application of an anonymous procedure.
  def convert_let_to_application(exp)
    # Extract lists of var names and values from the bindings of 'let'.
    # bindings is a (Scheme) list of 2-element (var val) lists.
    vars = []
    vals = []
    
    bindings = let_bindings(exp)
    while ! bindings.nil?
        vars << bindings.first.first
        vals << bindings.first.second.first
        bindings = bindings.second
    end
    lambda_expr = make_lambda(make_nested_pairs(*vars), let_body(exp))
    return make_nested_pairs(lambda_expr, *vals)
  end
  
end