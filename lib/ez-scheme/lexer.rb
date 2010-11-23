
class Token
  attr_accessor :_type, :value, :pos
  
  def initialize(_type, value, pos)
    @_type, @value, @pos = _type, value, pos
  end
  
  def to_s
    "#{_type}(#{value})"
  end
end

class LexerError < Exception
  attr_reader :pos
  def initialize(pos)
    @pos = pos
  end
end

class Lexer
  attr_reader :buf, :pos
  # rules is an array of [regex, type] pairs
  # regex is the re used to recognize the token
  # and type is the type of token to return
  def initialize(rules, skip_whitespace=true)
    # all the regexen are concat'd together into a single regex with capture groups
    idx = 1
    regex_parts = []
    @group_type = {}
    
    # /(?<user> [a-z]+ ){0} \g<user>/x
    rules.each do |(regex, _type)|
      groupname = "GROUP#{idx}"
      regex_parts << [groupname, regex]
      @group_type[groupname] = _type
      idx += 1
    end
    
    regexen = ""
    matcher = []
    regex_parts.each do |(groupname, regex)|
      regexen << "(?<#{groupname}> #{regex} ){0}\n"
      matcher << " \\g<#{groupname}> "
    end
    
    regexen << "#{matcher.join('|')}"
    @regex = Regexp.compile(regexen, Regexp::EXTENDED)
    @skip_whitespace = skip_whitespace
    @whitespace_re = /\S/
  end
  
  def input(buf)
    @buf = buf
    @pos = 0
  end
  
  def token
    if @pos >= buf.size
      return nil
    else
      if @skip_whitespace
        m = @whitespace_re.match(@buf[@pos..-1])
        if m
          @pos += m.pre_match.size
        else
          return nil
        end
      end
      
      m = @regex.match(@buf[@pos..-1])
      if m
        groupname = nil
        m.names.each {|n| m[n] ? (groupname = n; break) : nil }
        tok_type = @group_type[groupname]
        tok = Token.new(tok_type, m[groupname], @pos)
        @pos += m.end(0)
        return tok
      end
      
      raise LexerError.new(@pos)
      
    end
    
  end
  
  def tokens
    more = true
    while more
      tok = token
      break if tok.nil?
      yield tok
    end
  end
  
end


if __FILE__ == $0

l = Lexer.new [[/\d+/, :number], [/[a-zA-Z]+/, :letter], [/\(/, :lparen], [/\)/, :rparen]]

l.input "(assds) 123 dfdsf 123"

l.tokens {|tok| p tok }

end