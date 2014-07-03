# Copyright (c) Cognitect, Inc.
# All rights reserved.

module Transit
  class Wrapper
    extend Forwardable

    def_delegators :@value, :hash, :to_sym, :to_s

    attr_reader :value

    def initialize(value)
      @value = value
    end

    def ==(other)
      other.is_a?(self.class) && @value == other.value
    end
    alias eql? ==

    def inspect
      "<#{self.class} \"#{to_s}\">"
    end
  end

  class Quote < Wrapper; end

  class Symbol < Wrapper
    def initialize(sym)
      super sym.to_sym
    end

    def namespace
      @namespace ||= parsed[-2]
    end

    def name
      @name ||= parsed[-1] || "/"
    end

    private

    def parsed
      @parsed ||= @value.to_s.split("/")
    end
  end

  class ByteArray < Wrapper
    def self.from_base64(data)
      new(Base64.decode64(data))
    end

    def to_base64
      Base64.encode64(@value)
    end

    def to_s
      @value
    end
  end

  class List < Wrapper
    def to_a
      @value
    end
  end

  class TypedArray < Wrapper
    def initialize(t, ary)
      @type = t
      super ary
    end

    def type
      @type.to_s
    end

    def to_a
      @value
    end
  end

  class IntsArray < TypedArray
    def initialize(ary)
      super("ints", ary)
    end
  end

  class LongsArray < TypedArray
    def initialize(ary)
      super("longs", ary)
    end
  end

  class DoublesArray < TypedArray
    def initialize(ary)
      super("doubles", ary)
    end
  end

  class FloatsArray < TypedArray
    def initialize(ary)
      super("floats", ary)
    end
  end

  class BoolsArray < TypedArray
    def initialize(ary)
      super("bools", ary)
    end
  end

  class Char < Wrapper
    def initialize(c)
      raise ArgumentError.new("Char can only contain one character.") if c.length > 1
      super c
    end

    def to_s
      @value
    end
  end

  class UUID
    def self.random
      new
    end

    def initialize(uuid_or_most_significant_bits=nil,least_significant_bits=nil)
      case uuid_or_most_significant_bits
      when String
        @string_rep = uuid_or_most_significant_bits
      when Array
        @numeric_rep = uuid_or_most_significant_bits.map {|n| twos_complement(n)}
      when Numeric
        @numeric_rep = [twos_complement(uuid_or_most_significant_bits), twos_complement(least_significant_bits)]
      when nil
        @string_rep = SecureRandom.uuid
      else
        raise "Can't build UUID from #{uuid_or_most_significant_bits.inspect}"
      end
    end

    def to_s
      @string_rep ||= numbers_to_string
    end

    def most_significant_bits
      @most_significant_bits ||= numeric_rep[0]
    end

    def least_significant_bits
      @least_significant_bits ||= numeric_rep[1]
    end

    def inspect
      @inspect ||= "<#{self.class} \"#{to_s}\">"
    end

    def ==(other)
      return false unless other.is_a?(self.class)
      if @numeric_rep
        other.most_significant_bits == most_significant_bits &&
          other.least_significant_bits == least_significant_bits
      else
        other.to_s == @string_rep
      end
    end
    alias eql? ==

    def hash
      most_significant_bits.hash + least_significant_bits.hash
    end

    private

    def numeric_rep
      @numeric_rep ||= string_to_numbers
    end

    def numbers_to_string
      most_significant_bits = @numeric_rep[0]
      least_significant_bits = @numeric_rep[1]
      digits(most_significant_bits >> 32, 8) + "-" +
        digits(most_significant_bits >> 16, 4) + "-" +
        digits(most_significant_bits, 4)       + "-" +
        digits(least_significant_bits >> 48, 4) + "-" +
        digits(least_significant_bits, 12)
    end

    def string_to_numbers
      str = @string_rep.delete("-")
      [twos_complement(str[ 0..15].hex), twos_complement(str[16..31].hex)]
    end

    def digits(val, digits)
      hi = 1 << (digits*4)
      (hi | (val & (hi - 1))).to_s(16)[1..-1]
    end

    def twos_complement(integer_value, num_of_bits=64)
      max_signed   = 2**(num_of_bits-1)
      max_unsigned = 2**num_of_bits
      (integer_value >= max_signed) ? integer_value - max_unsigned : integer_value
    end
  end

  # Represents a hypermedia link, as per
  # {http://amundsen.com/media-types/collection/format/#arrays-links}
  class Link
    KEYS          = ["href", "rel", "name", "render", "prompt"]
    RENDER_VALUES = ["link", "image"]

    # @overload Link.new(hash)
    #   @param [Hash] hash
    #     Valid keys are:
    #       "href"   required, String or Addressable::URI
    #       "rel"    required, String
    #       "name"   optional, String
    #       "render" optional, String (only "link" or "image")
    #       "prompt" optional, String
    # @overload Link.new(href, rel, name, render, prompt)
    #   @param [String, Addressable::URI] href required
    #   @param [String] rel required
    #   @param [String] name optional
    #   @param [String] render optional (only "link" or "image")
    #   @param [String] prompt optional
    def initialize(*args)
      @values = if args[0].is_a?(Hash)
                  reconcile_values(args[0])
                elsif args.length >= 2 && (args[0].is_a?(Addressable::URI) || args[0].is_a?(String))
                  reconcile_values(Hash[KEYS.zip(args)])
                else
                  raise ArgumentError, "The first argument to Link.new can be a URI, String or a Hash. When the first argument is a URI or String, the second argument, rel, must present."
                end
    end

    def href;   @href   ||= @values["href"]   end
    def rel;    @rel    ||= @values["rel"]    end
    def name;   @name   ||= @values["name"]   end
    def render; @render ||= @values["render"] end
    def prompt; @prompt ||= @values["prompt"] end

    def to_h
      @values
    end

    def ==(other)
      other.is_a?(Link) && other.to_h == to_h
    end
    alias eql? ==

    def hash
      @values.hash
    end

    private

    def reconcile_values(map)
      map.dup.tap do |m|
        m["href"] = Addressable::URI.parse(m["href"]) if m["href"].is_a?(String)
        if m["render"]
          render = m["render"].downcase
          if RENDER_VALUES.include?(render)
            m["render"] = render
          else
            raise ArgumentError, "render must be either #{RENDER_VALUES[0]} or #{RENDER_VALUES[1]}"
          end
        end
      end.freeze
    end
  end

  # Represents a transit tag and value, with an optional string representation. Returned by
  # default when a reader encounters a tag for which there is no registered decoder. Can also
  # be used in a custom Handler implementation to force representation to use a transit ground
  # type using a rep for which there is no registered handler (e.g., an iterable for the
  # representation of an array).
  class TaggedValue
    attr_reader :tag, :rep
    def initialize(tag, rep)
      @tag = tag
      @rep = rep
    end

    def ==(other)
      other.is_a?(self.class) && other.tag == @tag && other.rep == @rep
    end
    alias eql? ==

    def hash
      @tag.hash + @rep.hash
    end
  end
end
