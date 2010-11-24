
class Environment
  # An environment in which variables are bound to values. Variable names
  # must be hashable, values are arbitrary objects.
  # 
  # Environment objects are linked via parent references. When bindings are
  # queried or assigned and the variable name isn't bound in the 
  # environment, the parent environment is recursively searched. 
  # 
  # All environment chains ultimately terminate in a "top-level" environment
  # which has None in its parent link.
  
  class Unbound < Exception; end
  
  attr_accessor :_binding, :parent
  
  def initialize(_binding, parent=nil)
    # Create a new environment with the given binding (dict var -> value)
    # and a reference to a parent environment.
    #
    @_binding = _binding
    @parent = parent
  end
  
  def lookup_var(var)
    # Looks up the bound value for the given variable, climbing up the
    # parent reference if required. 
    if res = @_binding[var]
      return res
    elsif ! @parent.nil?
      return @parent.lookup_var(var)
    else
      return nil
      #raise Unbound.new("unbound variable '#{var}'") 
    end           
  end
  
  def define_var(var, value)
    # Add a binding of var -> value to this environment. If a binding for 
    # the given var exists, it is replaced.
    @_binding[var] = value
  end
  
  def set_var_value(var, value)
    # Sets the value of var. If var is unbound in this environment, climbs
    # up the parent reference.
    if @_binding[var]
      @_binding[var] = value
    elsif ! @parent.nil?
      @parent.set_var_value(var, value)
    else
      raise Unbound.new("unbound variable '#{var}'")
    end
  end
  
end