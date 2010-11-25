require File.dirname(__FILE__) + '/lexer'
require File.dirname(__FILE__) + '/expr'

class ParseError < Exception; end


# Recursive-descent parser.
#
# Since Scheme code is also data, this parser mimics the (read) procedure
# and reads source code into Scheme expressions (internal data 
# representation suitable for further analysis). 
class SchemeParser
  
  attr_accessor :lexer, :text, :cur_token

  def initialize()
    @lexer = SchemeLexer.new()
    clear()
  end
  
  # Given a string with Scheme source code, parses it into a list of 
  # expression objects.            
  def parse(text)
    @text = text
    @lexer.input(@text)
    next_token
    parse_file
  end
  
  def clear()
    @text = ''
    @cur_token = nil
  end
  
  # Convert a lexing position (offset from start of text) into a 
  # coordinate [line %s, column %s].
  def pos2coord(pos)
    # Count the amount of newlines between the beginning of the parsed
    # text and pos. Then, count the column as an offset from the last 
    # newline
    #
    num_newlines = @text[0..pos].scan(%r{\n}).size
    line_offset = @text[0..pos].rindex("\n")
    line_offset = 0 if line_offset < 0
        
    "[line #{num_newlines + 1}, column #{pos - line_offset}]"
  end

  private
  
  def parse_error(msg, token=nil)
    token = token or cur_token
    if token
      coord = pos2coord(token.pos)
      raise ParseError.new("#{msg} #{coord}")
    else
      raise ParseError.new(msg)
    end
  end
  
  def next_token
    while true
      @cur_token = @lexer.token()
      if @cur_token.nil? or @cur_token._type != 'COMMENT'
        break
      end
    end
  rescue LexerError => e
    raise ParseError.new("syntax error at #{pos2coord(lexerr.pos)}")
  end
  
  # The 'match' primitive of RD parsers.   
  # * Verifies that the current token is of the given type 
  # * Returns the value of the current token
  # * Reads in the next token
  def match(_type)
    if @cur_token._type == _type
      val = @cur_token.value
      next_token()
      return val
    else
      parse_error("Unmatched #{_type} (found #{@cur_token.type})")
    end
  end
  
  ##
  ## Recursive parsing rules. The top-level is _parse_file, which expects
  ## a sequence of Scheme expressions. The rest of the rules follow section
  ## 7.1.2 of R5RS with some re-ordering for programming convenience.
  ##
  def parse_file()
    datum_list = []
    while @cur_token
      datum_list << datum()
    end
    datum_list
  end
      
  def datum()
    # list
    if @cur_token._type == 'LPAREN'
      return list()
    # abbreviation
    elsif @cur_token._type == 'QUOTE'
      return abbreviation()
    # simple datum
    else
      return simple_datum()
    end
  end
  
  def simple_datum()
    retval = nil
    if @cur_token._type == 'BOOLEAN'
      retval = Boolean.new(@cur_token.value == '#t')
    elsif @cur_token._type == 'NUMBER'
      base = 10
      num_str = @cur_token.value.to_s
      if num_str[0] == '#'
        if num_str[1] == 'x'
          base = 16
        elsif num_str[1] == 'o'
          base = 8
        elsif num_str[1] == 'b'
          base = 2
        end
        num_str = num_str[2..-1]
      end
      
      begin
        retval = Number.new(num_str.to_i(base))
      rescue ValueError => e
        parse_error('Invalid number')
      end
    elsif @cur_token._type == 'ID'
      retval = Sym.new(@cur_token.value)
    elsif @cur_token._type == 'STRING'
      retval = Sstring.new(@cur_token.value)
    else
      parse_error("Unexpected token '#{@cur_token.value}'")
    end
    
    next_token()
    retval
  end
  
  def list()
    # Algorithm:
    #
    # 1. First parse all sub-datums into a sequential Python list.
    # 2. Convert this list into nested Pair objects
    #
    # To handle the dot ('.'), dot_idx keeps track of the index in lst
    # where the dot was specified.
    # 
    match('LPAREN')
    lst = []
    dot_idx = -1
    
    while true
      if not @cur_token
        parse_error('Unmatched parentheses at end of input')
      elsif @cur_token._type == 'RPAREN'
        break
      elsif @cur_token._type == 'ID' and @cur_token.value == '.'
        if dot_idx > 0
          parse_error('Invalid usage of "."')
        end
        dot_idx = lst.size
        match('ID')
      else
        lst << datum()
      end
    end
    
    # Figure out whether we have a dotted list and whether the dot was 
    # placed correctly
    #
    dotted_end = false
    if dot_idx > 0
      if dot_idx == lst.size - 1
        dotted_end = true
      else
        parse_error('Invalid location for "." in list')
      end
    end
    
    match('RPAREN')
    
    cur_cdr = nil
    
    if dotted_end
      cur_cdr = lst[-1]
      lst = lst[0..-2]
    else
      cur_cdr = nil
    end

    lst.reverse.each do |datum|
      cur_cdr = Pair.new(datum, cur_cdr)
    end

    cur_cdr
  end
  
  def abbreviation()
    quotepos = @cur_token.pos
    match('QUOTE')
    datum = datum()
    Pair.new(Sym.new('quote'), Pair.new(datum, nil))
  end

end

# Partial Scheme lexer based on R5RS 7.1.1 (Lexical structure).
class SchemeLexer < Lexer

    def initialize
      rules = lexing_rules()
      super(rules, true)
    end
        
    def lexing_rules()
      # Regex helpers
      #
      digit_2 = %r{[0-1]}
      digit_8 = %r{[0-7]}
      digit_10 = %r{[0-9]}
      digit_16 = %r{[0-9A-Fa-f]}
      
      radix_2 = %r{\#b}
      radix_8 = %r{\#o}
      radix_10 = %r{(\#d)?}
      radix_16 = %r{\#x}
      
      number = %r{(#{radix_2}#{digit_2}+|#{radix_8}#{digit_8}+|#{radix_10}#{digit_10}+|#{radix_16}#{digit_16}+)}
      
      special_initial = '[!$%&*.:<=>?^_~]'
      initial = '([a-zA-Z]|'+special_initial+')'
      special_subsequent = '[+-.@]'
      subsequent = "(#{initial}|#{digit_10}|#{special_subsequent})"
      
      peculiar_identifier = '([+\-.]|\.\.\.)'
      identifier = "(#{initial}#{subsequent}*|#{peculiar_identifier})"
      
      special_initial = %r{#{special_initial}}
      special_subsequent = %r{#{special_subsequent}}
      peculiar_identifier = %r{#{peculiar_identifier}}
      rules = [
          [%r{;[^\n]*},                'COMMENT'],
          [%r{\#[tf]},                 'BOOLEAN'],
          [number,                     'NUMBER'],
          [identifier,                 'ID'],
          [%r{\(},                     'LPAREN'],
          [%r{\)},                     'RPAREN'],
          [%r{\'},                     'QUOTE'],
          [%r{\".*?\"},                'STRING']
      ]
      rules
    end

end
#-------------------------------------------------------------------------------
if __FILE__ == $0
  include Predicates
  p = SchemeParser.new
  res = p.parse %Q{
    (define (double num)
        (+ num num))

    (write (double 12))
  }
  require 'pp'
  p 'AST:'
  pp res
  puts 
  puts
  puts "scheme repr:"
  puts expr_repr(res)
end

