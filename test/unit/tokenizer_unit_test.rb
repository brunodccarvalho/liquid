# frozen_string_literal: true

require 'test_helper'

class TokenizerTest < Minitest::Test
  def test_tokenize_strings
    assert_equal([' '], tokenize(' '))
    assert_equal(['hello world'], tokenize('hello world'))
    assert_equal(['{}'], tokenize('{}'))
  end

  def test_tokenize_variables
    assert_equal(['{{funk}}'], tokenize('{{funk}}'))
    assert_equal([' ', '{{funk}}', ' '], tokenize(' {{funk}} '))
    assert_equal([' ', '{{funk}}', ' ', '{{so}}', ' ', '{{brother}}', ' '], tokenize(' {{funk}} {{so}} {{brother}} '))
    assert_equal([' ', '{{  funk  }}', ' '], tokenize(' {{  funk  }} '))
  end

  def test_tokenize_variables_with_strings_respect_quotes
    assert_equal([%q({{ "}}" "%}" "{%" }}), "y"], tokenize(%q({{ "}}" "%}" "{%" }}y)))
    assert_equal([%q({{ '}}' '%}' '{%' }}), "y"], tokenize(%q({{ '}}' '%}' '{%' }}y)))
    assert_equal([%q({{ ''}}), %q(' }}y)], tokenize(%q({{ ''}}' }}y)))
    assert_equal([%q({{ ""}}), %q(" }}y)], tokenize(%q({{ ""}}" }}y)))
    assert_equal([%q({{ '\'}}' }}), "y"],  tokenize(%q({{ '\'}}' }}y)))
    assert_equal([%q({{ "\"}}" }}), "y"],  tokenize(%q({{ "\"}}" }}y)))
  end

  def test_tokenize_tags_with_strings_do_not_respect_quotes
    assert_equal([%q({% a '%}), %q(' %}y)], tokenize(%q({% a '%}' %}y)))
    assert_equal([%q({% a "%}), %q(" %}y)], tokenize(%q({% a "%}" %}y)))
    assert_equal([%q({% a ''%}), %q(' %}y)], tokenize(%q({% a ''%}' %}y)))
    assert_equal([%q({% a ""%}), %q(" %}y)], tokenize(%q({% a ""%}" %}y)))
    assert_equal([%q({% a '\'%}), %q(' %}y)], tokenize(%q({% a '\'%}' %}y)))
    assert_equal([%q({% a "\"%}), %q(" %}y)], tokenize(%q({% a "\"%}" %}y)))
  end

  def test_tokenize_raw_tags
    assert_equal([%q({% raw %}),
                  %q({% endraw %}),
                  "y"], tokenize(%q({% raw %}{% endraw %}y)))
    assert_equal([%q({% raw } % }} %}),
                   %q(}} %} {{ {% z),
                  %q({% endraw ... %}),
                  "y"], tokenize(%q({% raw } % }} %}}} %} {{ {% z{% endraw ... %}y)))
    assert_equal([%({%-\nraw } % }}\n-%}),
                   %(}} %} {{ {% z),
                  %({%-\nendraw ...\n-%}),
                  "y"], tokenize(%({%-\nraw } % }}\n-%}}} %} {{ {% z{%-\nendraw ...\n-%}y)))
    assert_equal([%q({% raw %}),
                   %q({{ "),
                  %q({% endraw %}),
                   %q(" }}),
                  %q({% endraw %}),
                  "y"], tokenize(%q({% raw %}{{ "{% endraw %}" }}{% endraw %}y)))
    assert_equal([%q({% raw %}),
                   %q({% "),
                  %q({% endraw %}),
                   %q(" %}),
                  %q({% endraw %}),
                  "y"], tokenize(%q({% raw %}{% "{% endraw %}" %}{% endraw %}y)))
  end

  def test_tokenize_blocks
    assert_equal(['{%comment%}'], tokenize('{%comment%}'))
    assert_equal([' ', '{%comment%}', ' '], tokenize(' {%comment%} '))

    assert_equal([' ', '{%comment%}', ' ', '{%endcomment%}', ' '], tokenize(' {%comment%} {%endcomment%} '))
    assert_equal(['  ', '{% comment %}', ' ', '{% endcomment %}', ' '], tokenize("  {% comment %} {% endcomment %} "))
  end

  def test_calculate_line_numbers_per_token_with_profiling
    assert_equal([1],       tokenize_line_numbers("{{funk}}"))
    assert_equal([1, 1, 1], tokenize_line_numbers(" {{funk}} "))
    assert_equal([1, 2, 2], tokenize_line_numbers("\n{{funk}}\n"))
    assert_equal([1, 1, 3], tokenize_line_numbers(" {{\n funk \n}} "))
  end

  def test_tokenize_with_nil_source_returns_empty_array
    assert_equal([], tokenize(nil))
  end

  def test_incomplete_curly_braces
    assert_equal(["x", "{{"], tokenize('x{{.} '))
    assert_equal(["x", "{{"], tokenize('x{{}%}'))
    assert_equal(["{{}}", "}"], tokenize('{{}}}'))
  end

  def test_unmatching_start_and_end
    assert_equal(["{{"], tokenize('{{%}'))
    assert_equal(["{{%%%}}"], tokenize('{{%%%}}'))
    assert_equal(["{%", "}}"], tokenize('{%}}'))
    assert_equal(["{%%}", "}"], tokenize('{%%}}'))
  end

  private

  def new_tokenizer(source, parse_context: Liquid::ParseContext.new, start_line_number: nil)
    parse_context.new_tokenizer(source, start_line_number: start_line_number)
  end

  def tokenize(source)
    tokenizer = new_tokenizer(source)
    tokens    = []
    # shift is private in Liquid::C::Tokenizer, since it is only for unit testing
    while (t = tokenizer.send(:shift))
      tokens << t
    end
    tokens
  end

  def tokenize_line_numbers(source)
    tokenizer    = new_tokenizer(source, start_line_number: 1)
    line_numbers = []
    loop do
      line_number = tokenizer.line_number
      if tokenizer.send(:shift)
        line_numbers << line_number
      else
        break
      end
    end
    line_numbers
  end
end
