# frozen_string_literal: true

require "strscan"

module Liquid
  class Tokenizer
    attr_reader :line_number, :for_liquid_tag

    TAG_OR_VARIABLE_START = /\{[\{\%]/
    VARIABLE_CHARACTER_STOPS = /[\\"'\}\{]/

    RAW_TAG_LEADING = %r{\A-?\s*raw\b}m
    ENDRAW_TAG_LEADING = /\A-?\s*endraw\b/m

    OPEN_CURLEY = "{".ord
    CLOSE_CURLEY = "}".ord
    PERCENTAGE = "%".ord
    DOUBLE_QUOTE = '"'.ord
    SINGLE_QUOTE = "'".ord
    ESCAPE = "\\".ord

    def initialize(
      source:,
      string_scanner:,
      line_numbers: false,
      line_number: nil,
      for_liquid_tag: false
    )
      @line_number = line_number || (line_numbers ? 1 : nil)
      @for_liquid_tag = for_liquid_tag
      @source = source.to_s.to_str
      @offset = 0
      @tokens = []

      if @source
        @ss = string_scanner
        @ss.string = @source
        tokenize
      end
    end

    def shift
      token = @tokens[@offset]

      return unless token

      @offset += 1

      if @line_number
        @line_number += @for_liquid_tag ? 1 : token.count("\n")
      end

      token
    end

    private

    def tokenize
      if @for_liquid_tag
        @tokens = @source.split("\n")
      else
        scan_top_level_tokens until @ss.eos?
      end

      @source = nil
      @ss = nil
    end

    def scan_top_level_tokens
      if @ss.peek_byte == OPEN_CURLEY
        @ss.scan_byte

        byte_b = @ss.peek_byte

        if byte_b == PERCENTAGE
          @ss.scan_byte
          @raw_tag = check_raw_tag_leading?
          @tokens << scan_tag_token
          scan_raw_content_and_endraw_token if @raw_tag
          return
        elsif byte_b == OPEN_CURLEY
          @ss.scan_byte
          @tokens << scan_variable_token
          return
        end

        @ss.pos -= 1
      end

      @tokens << scan_text_token
    end

    def scan_text_token
      start = @ss.pos

      unless @ss.skip_until(TAG_OR_VARIABLE_START)
        token = @ss.rest
        @ss.terminate
        return token
      end

      pos = @ss.pos -= 2
      @source.byteslice(start, pos - start)
    rescue ::ArgumentError => e
      if e.message == "invalid byte sequence in #{@ss.string.encoding}"
        raise SyntaxError, "Invalid byte sequence in #{@ss.string.encoding}"
      else
        raise
      end
    end

    def scan_variable_token
      start = @ss.pos - 2
      string_quote = nil

      until @ss.eos?
        case skip_to_byte(VARIABLE_CHARACTER_STOPS)
        when ESCAPE
          @ss.pos += 1 if string_quote
        when DOUBLE_QUOTE
          if string_quote == DOUBLE_QUOTE
            string_quote = nil
          elsif !string_quote
            string_quote = DOUBLE_QUOTE
          end
        when SINGLE_QUOTE
          if string_quote == SINGLE_QUOTE
            string_quote = nil
          elsif !string_quote
            string_quote = SINGLE_QUOTE
          end
        when CLOSE_CURLEY
          if !string_quote && @ss.peek_byte == CLOSE_CURLEY
            @ss.pos += 1
            return @source.byteslice(start, @ss.pos - start)
          end
        when OPEN_CURLEY
          if !string_quote && @ss.peek_byte == PERCENTAGE
            # for backward compatibility. it will not parse properly later.
            @ss.pos += 1
            return scan_tag_token(start)
          end
        else
          @ss.terminate
          break
        end
      end

      "{{"
    end

    def scan_tag_token(start = nil)
      start ||= @ss.pos - 2

      if (len = @ss.skip_until("%}"))
        return @source.byteslice(start, len + 2)
      end

      "{%"
    end

    def scan_raw_content_and_endraw_token
      @raw_tag = false
      start = @ss.pos

      while @ss.skip_until("{%")
        next unless @ss.match?(ENDRAW_TAG_LEADING)

        @tokens << @source.byteslice(start, @ss.pos - 2 - start) if start < @ss.pos - 2
        @tokens << scan_tag_token
        return
      end

      @tokens << @source.byteslice(start)
      @ss.terminate
    end

    def skip_to_byte(byte_pattern)
      if @ss.skip_until(byte_pattern)
        @ss.pos -= 1
        @ss.scan_byte
      end
    end

    def check_raw_tag_leading?
      @ss.match?(RAW_TAG_LEADING)
    end
  end
end
