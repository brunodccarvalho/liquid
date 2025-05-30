# encoding: utf-8
# frozen_string_literal: true

require 'test_helper'

class TestThing
  attr_reader :foo

  def initialize
    @foo = 0
  end

  def to_s
    "woot: #{@foo}"
  end

  def [](_whatever)
    to_s
  end

  def to_liquid
    @foo += 1
    self
  end
end

class TestDrop < Liquid::Drop
  def initialize(value:)
    @value = value
  end

  attr_reader :value

  def registers
    "{#{@value.inspect}=>#{@context.registers[@value].inspect}}"
  end
end

class TestModel
  def initialize(value:)
    @value = value
  end

  def to_liquid
    TestDrop.new(value: @value)
  end
end

class TestEnumerable < Liquid::Drop
  include Enumerable

  def each(&block)
    [{ "foo" => 1, "bar" => 2 }, { "foo" => 2, "bar" => 1 }, { "foo" => 3, "bar" => 3 }].each(&block)
  end
end

class NumberLikeThing < Liquid::Drop
  def initialize(amount)
    @amount = amount
  end

  def to_number
    @amount
  end
end

class StandardFiltersTest < Minitest::Test
  Filters = Class.new(Liquid::StrainerTemplate)
  Filters.add_filter(Liquid::StandardFilters)

  include Liquid

  def setup
    @filters = Filters.new(Context.new)
  end

  def test_size
    assert_equal(3, @filters.size([1, 2, 3]))
    assert_equal(0, @filters.size([]))
    assert_equal(0, @filters.size(nil))
  end

  def test_downcase
    assert_equal('testing', @filters.downcase("Testing"))
    assert_equal('', @filters.downcase(nil))
  end

  def test_upcase
    assert_equal('TESTING', @filters.upcase("Testing"))
    assert_equal('', @filters.upcase(nil))
  end

  def test_slice
    assert_equal('oob', @filters.slice('foobar', 1, 3))
    assert_equal('oobar', @filters.slice('foobar', 1, 1000))
    assert_equal('', @filters.slice('foobar', 1, 0))
    assert_equal('o', @filters.slice('foobar', 1, 1))
    assert_equal('bar', @filters.slice('foobar', 3, 3))
    assert_equal('ar', @filters.slice('foobar', -2, 2))
    assert_equal('ar', @filters.slice('foobar', -2, 1000))
    assert_equal('r', @filters.slice('foobar', -1))
    assert_equal('', @filters.slice(nil, 0))
    assert_equal('', @filters.slice('foobar', 100, 10))
    assert_equal('', @filters.slice('foobar', -100, 10))
    assert_equal('oob', @filters.slice('foobar', '1', '3'))
    assert_raises(Liquid::ArgumentError) do
      @filters.slice('foobar', nil)
    end
    assert_raises(Liquid::ArgumentError) do
      @filters.slice('foobar', 0, "")
    end
    assert_equal("", @filters.slice("foobar", 0, -(1 << 64)))
    assert_equal("foobar", @filters.slice("foobar", 0, 1 << 63))
    assert_equal("", @filters.slice("foobar", 1 << 63, 6))
    assert_equal("", @filters.slice("foobar", -(1 << 63), 6))
  end

  def test_slice_on_arrays
    input = 'foobar'.split(//)
    assert_equal(%w(o o b), @filters.slice(input, 1, 3))
    assert_equal(%w(o o b a r), @filters.slice(input, 1, 1000))
    assert_equal(%w(), @filters.slice(input, 1, 0))
    assert_equal(%w(o), @filters.slice(input, 1, 1))
    assert_equal(%w(b a r), @filters.slice(input, 3, 3))
    assert_equal(%w(a r), @filters.slice(input, -2, 2))
    assert_equal(%w(a r), @filters.slice(input, -2, 1000))
    assert_equal(%w(r), @filters.slice(input, -1))
    assert_equal(%w(), @filters.slice(input, 100, 10))
    assert_equal(%w(), @filters.slice(input, -100, 10))
    assert_equal([], @filters.slice(input, 0, -(1 << 64)))
    assert_equal(input, @filters.slice(input, 0, 1 << 63))
    assert_equal([], @filters.slice(input, 1 << 63, 6))
    assert_equal([], @filters.slice(input, -(1 << 63), 6))
  end

  def test_find_on_empty_array
    assert_nil(@filters.find([], 'foo', 'bar'))
  end

  def test_find_index_on_empty_array
    assert_nil(@filters.find_index([], 'foo', 'bar'))
  end

  def test_has_on_empty_array
    refute(@filters.has([], 'foo', 'bar'))
  end

  def test_truncate
    assert_equal('1234...', @filters.truncate('1234567890', 7))
    assert_equal('1234567890', @filters.truncate('1234567890', 20))
    assert_equal('...', @filters.truncate('1234567890', 0))
    assert_equal('1234567890', @filters.truncate('1234567890'))
    assert_equal("测试...", @filters.truncate("测试测试测试测试", 5))
    assert_equal('12341', @filters.truncate("1234567890", 5, 1))
    assert_equal("foobar", @filters.truncate("foobar", 1 << 63))
    assert_equal("...", @filters.truncate("foobar", -(1 << 63)))
  end

  def test_split
    assert_equal(['12', '34'], @filters.split('12~34', '~'))
    assert_equal(['A? ', ' ,Z'], @filters.split('A? ~ ~ ~ ,Z', '~ ~ ~'))
    assert_equal(['A?Z'], @filters.split('A?Z', '~'))
    assert_equal([], @filters.split(nil, ' '))
    assert_equal(['A', 'Z'], @filters.split('A1Z', 1))
  end

  def test_escape
    assert_equal('&lt;strong&gt;', @filters.escape('<strong>'))
    assert_equal('1', @filters.escape(1))
    assert_equal('2001-02-03', @filters.escape(Date.new(2001, 2, 3)))
    assert_nil(@filters.escape(nil))
  end

  def test_h
    assert_equal('&lt;strong&gt;', @filters.h('<strong>'))
    assert_equal('1', @filters.h(1))
    assert_equal('2001-02-03', @filters.h(Date.new(2001, 2, 3)))
    assert_nil(@filters.h(nil))
  end

  def test_escape_once
    assert_equal('&lt;strong&gt;Hulk&lt;/strong&gt;', @filters.escape_once('&lt;strong&gt;Hulk</strong>'))
  end

  def test_base64_encode
    assert_equal('b25lIHR3byB0aHJlZQ==', @filters.base64_encode('one two three'))
    assert_equal('', @filters.base64_encode(nil))
  end

  def test_base64_decode
    decoded = @filters.base64_decode('b25lIHR3byB0aHJlZQ==')
    assert_equal('one two three', decoded)
    assert_equal(Encoding::UTF_8, decoded.encoding)

    decoded = @filters.base64_decode('4pyF')
    assert_equal('✅', decoded)
    assert_equal(Encoding::UTF_8, decoded.encoding)

    decoded = @filters.base64_decode("/w==")
    assert_equal(Encoding::ASCII_8BIT, decoded.encoding)
    assert_equal((+"\xFF").force_encoding(Encoding::ASCII_8BIT), decoded)

    exception = assert_raises(Liquid::ArgumentError) do
      @filters.base64_decode("invalidbase64")
    end

    assert_equal('Liquid error: invalid base64 provided to base64_decode', exception.message)
  end

  def test_base64_url_safe_encode
    assert_equal(
      'YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXogQUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVogMTIzNDU2Nzg5MCAhQCMkJV4mKigpLT1fKy8_Ljo7W117fVx8',
      @filters.base64_url_safe_encode('abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890 !@#$%^&*()-=_+/?.:;[]{}\|'),
    )
    assert_equal('', @filters.base64_url_safe_encode(nil))
  end

  def test_base64_url_safe_decode
    decoded = @filters.base64_url_safe_decode('YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXogQUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVogMTIzNDU2Nzg5MCAhQCMkJV4mKigpLT1fKy8_Ljo7W117fVx8')
    assert_equal(
      'abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890 !@#$%^&*()-=_+/?.:;[]{}\|',
      decoded,
    )
    assert_equal(Encoding::UTF_8, decoded.encoding)

    decoded = @filters.base64_url_safe_decode('4pyF')
    assert_equal('✅', decoded)
    assert_equal(Encoding::UTF_8, decoded.encoding)

    decoded = @filters.base64_url_safe_decode("_w==")
    assert_equal(Encoding::ASCII_8BIT, decoded.encoding)
    assert_equal((+"\xFF").force_encoding(Encoding::ASCII_8BIT), decoded)

    exception = assert_raises(Liquid::ArgumentError) do
      @filters.base64_url_safe_decode("invalidbase64")
    end
    assert_equal('Liquid error: invalid base64 provided to base64_url_safe_decode', exception.message)
  end

  def test_url_encode
    assert_equal('foo%2B1%40example.com', @filters.url_encode('foo+1@example.com'))
    assert_equal('1', @filters.url_encode(1))
    assert_equal('2001-02-03', @filters.url_encode(Date.new(2001, 2, 3)))
    assert_nil(@filters.url_encode(nil))
  end

  def test_url_decode
    assert_equal('foo bar', @filters.url_decode('foo+bar'))
    assert_equal('foo bar', @filters.url_decode('foo%20bar'))
    assert_equal('foo+1@example.com', @filters.url_decode('foo%2B1%40example.com'))
    assert_equal('1', @filters.url_decode(1))
    assert_equal('2001-02-03', @filters.url_decode(Date.new(2001, 2, 3)))
    assert_nil(@filters.url_decode(nil))
    exception = assert_raises(Liquid::ArgumentError) do
      @filters.url_decode('%ff')
    end
    assert_equal('Liquid error: invalid byte sequence in UTF-8', exception.message)
  end

  def test_truncatewords
    assert_equal('one two three', @filters.truncatewords('one two three', 4))
    assert_equal('one two...', @filters.truncatewords('one two three', 2))
    assert_equal('one two three', @filters.truncatewords('one two three'))
    assert_equal(
      'Two small (13&#8221; x 5.5&#8221; x 10&#8221; high) baskets fit inside one large basket (13&#8221;...',
      @filters.truncatewords('Two small (13&#8221; x 5.5&#8221; x 10&#8221; high) baskets fit inside one large basket (13&#8221; x 16&#8221; x 10.5&#8221; high) with cover.', 15),
    )
    assert_equal("测试测试测试测试", @filters.truncatewords('测试测试测试测试', 5))
    assert_equal('one two1', @filters.truncatewords("one two three", 2, 1))
    assert_equal('one two three...', @filters.truncatewords("one  two\tthree\nfour", 3))
    assert_equal('one two...', @filters.truncatewords("one two three four", 2))
    assert_equal('one...', @filters.truncatewords("one two three four", 0))
    assert_equal('one two three four', @filters.truncatewords("one two three four", 1 << 31))
    assert_equal('one...', @filters.truncatewords("one two three four", -(1 << 32)))
  end

  def test_strip_html
    assert_equal('test', @filters.strip_html("<div>test</div>"))
    assert_equal('test', @filters.strip_html("<div id='test'>test</div>"))
    assert_equal('', @filters.strip_html("<script type='text/javascript'>document.write('some stuff');</script>"))
    assert_equal('', @filters.strip_html("<style type='text/css'>foo bar</style>"))
    assert_equal('test', @filters.strip_html("<div\nclass='multiline'>test</div>"))
    assert_equal('test', @filters.strip_html("<!-- foo bar \n test -->test"))
    assert_equal('', @filters.strip_html(nil))

    # Quirk of the existing implementation
    assert_equal('foo;', @filters.strip_html("<<<script </script>script>foo;</script>"))
  end

  def test_join
    assert_equal('1 2 3 4', @filters.join([1, 2, 3, 4]))
    assert_equal('1 - 2 - 3 - 4', @filters.join([1, 2, 3, 4], ' - '))
    assert_equal('1121314', @filters.join([1, 2, 3, 4], 1))
  end

  def test_join_calls_to_liquid_on_each_element
    drop = Class.new(Liquid::Drop) do
      def to_liquid
        'i did it'
      end
    end

    assert_equal('i did it, i did it', @filters.join([drop.new, drop.new], ", "))
  end

  def test_sort
    assert_equal([1, 2, 3, 4], @filters.sort([4, 3, 2, 1]))
    assert_equal([{ "a" => 1 }, { "a" => 2 }, { "a" => 3 }, { "a" => 4 }], @filters.sort([{ "a" => 4 }, { "a" => 3 }, { "a" => 1 }, { "a" => 2 }], "a"))
  end

  def test_sort_with_nils
    assert_equal([1, 2, 3, 4, nil], @filters.sort([nil, 4, 3, 2, 1]))
    assert_equal([{ "a" => 1 }, { "a" => 2 }, { "a" => 3 }, { "a" => 4 }, {}], @filters.sort([{ "a" => 4 }, { "a" => 3 }, {}, { "a" => 1 }, { "a" => 2 }], "a"))
  end

  def test_sort_when_property_is_sometimes_missing_puts_nils_last
    input       = [
      { "price" => 4, "handle" => "alpha" },
      { "handle" => "beta" },
      { "price" => 1, "handle" => "gamma" },
      { "handle" => "delta" },
      { "price" => 2, "handle" => "epsilon" },
    ]
    expectation = [
      { "price" => 1, "handle" => "gamma" },
      { "price" => 2, "handle" => "epsilon" },
      { "price" => 4, "handle" => "alpha" },
      { "handle" => "beta" },
      { "handle" => "delta" },
    ]
    assert_equal(expectation, @filters.sort(input, "price"))
  end

  def test_sort_natural
    assert_equal(["a", "B", "c", "D"], @filters.sort_natural(["c", "D", "a", "B"]))
    assert_equal([{ "a" => "a" }, { "a" => "B" }, { "a" => "c" }, { "a" => "D" }], @filters.sort_natural([{ "a" => "D" }, { "a" => "c" }, { "a" => "a" }, { "a" => "B" }], "a"))
  end

  def test_sort_natural_with_nils
    assert_equal(["a", "B", "c", "D", nil], @filters.sort_natural([nil, "c", "D", "a", "B"]))
    assert_equal([{ "a" => "a" }, { "a" => "B" }, { "a" => "c" }, { "a" => "D" }, {}], @filters.sort_natural([{ "a" => "D" }, { "a" => "c" }, {}, { "a" => "a" }, { "a" => "B" }], "a"))
  end

  def test_sort_natural_when_property_is_sometimes_missing_puts_nils_last
    input       = [
      { "price" => "4", "handle" => "alpha" },
      { "handle" => "beta" },
      { "price" => "1", "handle" => "gamma" },
      { "handle" => "delta" },
      { "price" => 2, "handle" => "epsilon" },
    ]
    expectation = [
      { "price" => "1", "handle" => "gamma" },
      { "price" => 2, "handle" => "epsilon" },
      { "price" => "4", "handle" => "alpha" },
      { "handle" => "beta" },
      { "handle" => "delta" },
    ]
    assert_equal(expectation, @filters.sort_natural(input, "price"))
  end

  def test_sort_natural_case_check
    input = [
      { "key" => "X" },
      { "key" => "Y" },
      { "key" => "Z" },
      { "fake" => "t" },
      { "key" => "a" },
      { "key" => "b" },
      { "key" => "c" },
    ]
    expectation = [
      { "key" => "a" },
      { "key" => "b" },
      { "key" => "c" },
      { "key" => "X" },
      { "key" => "Y" },
      { "key" => "Z" },
      { "fake" => "t" },
    ]
    assert_equal(expectation, @filters.sort_natural(input, "key"))
    assert_equal(["a", "b", "c", "X", "Y", "Z"], @filters.sort_natural(["X", "Y", "Z", "a", "b", "c"]))
  end

  def test_sort_empty_array
    assert_equal([], @filters.sort([], "a"))
  end

  def test_sort_invalid_property
    foo = [
      [1],
      [2],
      [3],
    ]

    assert_raises(Liquid::ArgumentError) do
      @filters.sort(foo, "bar")
    end
  end

  def test_sort_natural_empty_array
    assert_equal([], @filters.sort_natural([], "a"))
  end

  def test_sort_natural_invalid_property
    foo = [
      [1],
      [2],
      [3],
    ]

    assert_raises(Liquid::ArgumentError) do
      @filters.sort_natural(foo, "bar")
    end
  end

  def test_legacy_sort_hash
    assert_equal([{ a: 1, b: 2 }], @filters.sort(a: 1, b: 2))
  end

  def test_numerical_vs_lexicographical_sort
    assert_equal([2, 10], @filters.sort([10, 2]))
    assert_equal([{ "a" => 2 }, { "a" => 10 }], @filters.sort([{ "a" => 10 }, { "a" => 2 }], "a"))
    assert_equal(["10", "2"], @filters.sort(["10", "2"]))
    assert_equal([{ "a" => "10" }, { "a" => "2" }], @filters.sort([{ "a" => "10" }, { "a" => "2" }], "a"))
  end

  def test_uniq
    assert_equal(["foo"], @filters.uniq("foo"))
    assert_equal([1, 3, 2, 4], @filters.uniq([1, 1, 3, 2, 3, 1, 4, 3, 2, 1]))
    assert_equal([{ "a" => 1 }, { "a" => 3 }, { "a" => 2 }], @filters.uniq([{ "a" => 1 }, { "a" => 3 }, { "a" => 1 }, { "a" => 2 }], "a"))
    test_drop = TestDrop.new(value: "test")
    test_drop_alternate = TestDrop.new(value: "test")
    assert_equal([test_drop], @filters.uniq([test_drop, test_drop_alternate], 'value'))
  end

  def test_uniq_empty_array
    assert_equal([], @filters.uniq([], "a"))
  end

  def test_uniq_invalid_property
    foo = [
      [1],
      [2],
      [3],
    ]

    assert_raises(Liquid::ArgumentError) do
      @filters.uniq(foo, "bar")
    end
  end

  def test_compact_empty_array
    assert_equal([], @filters.compact([], "a"))
  end

  def test_compact_invalid_property
    foo = [
      [1],
      [2],
      [3],
    ]

    assert_raises(Liquid::ArgumentError) do
      @filters.compact(foo, "bar")
    end
  end

  def test_reverse
    assert_equal([4, 3, 2, 1], @filters.reverse([1, 2, 3, 4]))
  end

  def test_legacy_reverse_hash
    assert_equal([{ a: 1, b: 2 }], @filters.reverse(a: 1, b: 2))
  end

  def test_map
    assert_equal([1, 2, 3, 4], @filters.map([{ "a" => 1 }, { "a" => 2 }, { "a" => 3 }, { "a" => 4 }], 'a'))
    assert_template_result(
      'abc',
      "{{ ary | map:'foo' | map:'bar' }}",
      { 'ary' => [{ 'foo' => { 'bar' => 'a' } }, { 'foo' => { 'bar' => 'b' } }, { 'foo' => { 'bar' => 'c' } }] },
    )
  end

  def test_map_doesnt_call_arbitrary_stuff
    assert_template_result("", '{{ "foo" | map: "__id__" }}')
    assert_template_result("", '{{ "foo" | map: "inspect" }}')
  end

  def test_map_calls_to_liquid
    t = TestThing.new
    assert_template_result("woot: 1", '{{ foo | map: "whatever" }}', { "foo" => [t] })
  end

  def test_map_calls_context=
    model = TestModel.new(value: :test)

    template = Template.parse('{{ foo | map: "registers" }}')
    template.registers[:test] = 1234
    template.assigns['foo'] = [model]

    assert_template_result("{:test=>1234}", template.render!)
  end

  def test_map_on_hashes
    assert_template_result(
      "4217",
      '{{ thing | map: "foo" | map: "bar" }}',
      { "thing" => { "foo" => [{ "bar" => 42 }, { "bar" => 17 }] } },
    )
  end

  def test_legacy_map_on_hashes_with_dynamic_key
    template = "{% assign key = 'foo' %}{{ thing | map: key | map: 'bar' }}"
    hash     = { "foo" => { "bar" => 42 } }
    assert_template_result("42", template, { "thing" => hash })
  end

  def test_sort_calls_to_liquid
    t = TestThing.new
    Liquid::Template.parse('{{ foo | sort: "whatever" }}').render("foo" => [t])
    assert(t.foo > 0)
  end

  def test_map_over_proc
    drop  = TestDrop.new(value: "testfoo")
    p     = proc { drop }
    output = Liquid::Template.parse('{{ procs | map: "value" }}').render!({ "procs" => [p] })
    assert_equal("testfoo", output)
  end

  def test_map_over_drops_returning_procs
    drops = [
      {
        "proc" => -> { "foo" },
      },
      {
        "proc" => -> { "bar" },
      },
    ]
    output = Liquid::Template.parse('{{ drops | map: "proc" }}').render!({ "drops" => drops })
    assert_equal("foobar", output)
  end

  def test_map_works_on_enumerables
    output = Liquid::Template.parse('{{ foo | map: "foo" }}').render!({ "foo" => TestEnumerable.new })
    assert_equal("123", output)
  end

  def test_map_returns_empty_on_2d_input_array
    foo = [
      [1],
      [2],
      [3],
    ]

    assert_raises(Liquid::ArgumentError) do
      @filters.map(foo, "bar")
    end
  end

  def test_map_with_nil_property
    array = [
      { "handle" => "alpha", "value" => "A" },
      { "handle" => "beta", "value" => "B" },
      { "handle" => "gamma", "value" => "C" }
    ]

    assert_template_result("alpha beta gamma", "{{ array | map: nil | map: 'handle' | join: ' ' }}", { "array" => array })
  end

  def test_map_with_empty_string_property
    array = [
      { "handle" => "alpha", "value" => "A" },
      { "handle" => "beta", "value" => "B" },
      { "handle" => "gamma", "value" => "C" }
    ]

    assert_template_result("alpha beta gamma", "{{ array | map: '' | map: 'handle' | join: ' ' }}", { "array" => array })
  end

  def test_map_with_value_property
    array = [
      { "handle" => "alpha", "value" => "A" },
      { "handle" => "beta", "value" => "B" },
      { "handle" => "gamma", "value" => "C" }
    ]

    assert_template_result("A B C", "{{ array | map: 'value' | join: ' ' }}", { "array" => array })
  end

  def test_map_returns_input_with_no_property
    input = [
      [1],
      [2],
      [3],
    ]
    result = @filters.map(input, nil)
    assert_equal(input.flatten, result)

    result = @filters.map(input, '')
    assert_equal(input.flatten, result)
  end

  def test_sort_works_on_enumerables
    assert_template_result("213", '{{ foo | sort: "bar" | map: "foo" }}', { "foo" => TestEnumerable.new })
  end

  def test_first_and_last_call_to_liquid
    assert_template_result('foobar', '{{ foo | first }}', { 'foo' => [ThingWithToLiquid.new] })
    assert_template_result('foobar', '{{ foo | last }}', { 'foo' => [ThingWithToLiquid.new] })
  end

  def test_truncate_calls_to_liquid
    assert_template_result("wo...", '{{ foo | truncate: 5 }}', { "foo" => TestThing.new })
  end

  def test_date
    assert_equal('May', @filters.date(Time.parse("2006-05-05 10:00:00"), "%B"))
    assert_equal('June', @filters.date(Time.parse("2006-06-05 10:00:00"), "%B"))
    assert_equal('July', @filters.date(Time.parse("2006-07-05 10:00:00"), "%B"))

    assert_equal('May', @filters.date("2006-05-05 10:00:00", "%B"))
    assert_equal('June', @filters.date("2006-06-05 10:00:00", "%B"))
    assert_equal('July', @filters.date("2006-07-05 10:00:00", "%B"))

    assert_equal('2006-07-05 10:00:00', @filters.date("2006-07-05 10:00:00", ""))
    assert_equal('2006-07-05 10:00:00', @filters.date("2006-07-05 10:00:00", ""))
    assert_equal('2006-07-05 10:00:00', @filters.date("2006-07-05 10:00:00", ""))
    assert_equal('2006-07-05 10:00:00', @filters.date("2006-07-05 10:00:00", nil))

    assert_equal('07/05/2006', @filters.date("2006-07-05 10:00:00", "%m/%d/%Y"))

    assert_equal("07/16/2004", @filters.date("Fri Jul 16 01:00:00 2004", "%m/%d/%Y"))
    assert_equal(Date.today.year.to_s, @filters.date('now', '%Y'))
    assert_equal(Date.today.year.to_s, @filters.date('today', '%Y'))
    assert_equal(Date.today.year.to_s, @filters.date('Today', '%Y'))

    assert_nil(@filters.date(nil, "%B"))

    assert_equal('', @filters.date('', "%B"))

    with_timezone("UTC") do
      assert_equal("07/05/2006", @filters.date(1152098955, "%m/%d/%Y"))
      assert_equal("07/05/2006", @filters.date("1152098955", "%m/%d/%Y"))
    end
  end

  def test_first_last
    assert_equal(1, @filters.first([1, 2, 3]))
    assert_equal(3, @filters.last([1, 2, 3]))
    assert_nil(@filters.first([]))
    assert_nil(@filters.last([]))
  end

  def test_replace
    assert_equal('b b b b', @filters.replace('a a a a', 'a', 'b'))
    assert_equal('2 2 2 2', @filters.replace('1 1 1 1', 1, 2))
    assert_equal('1 1 1 1', @filters.replace('1 1 1 1', 2, 3))
    assert_template_result('2 2 2 2', "{{ '1 1 1 1' | replace: '1', 2 }}")

    assert_equal('b a a a', @filters.replace_first('a a a a', 'a', 'b'))
    assert_equal('2 1 1 1', @filters.replace_first('1 1 1 1', 1, 2))
    assert_equal('1 1 1 1', @filters.replace_first('1 1 1 1', 2, 3))
    assert_template_result('2 1 1 1', "{{ '1 1 1 1' | replace_first: '1', 2 }}")

    assert_equal('a a a b', @filters.replace_last('a a a a', 'a', 'b'))
    assert_equal('1 1 1 2', @filters.replace_last('1 1 1 1', 1, 2))
    assert_equal('1 1 1 1', @filters.replace_last('1 1 1 1', 2, 3))
    assert_template_result('1 1 1 2', "{{ '1 1 1 1' | replace_last: '1', 2 }}")
  end

  def test_remove
    assert_equal('   ', @filters.remove("a a a a", 'a'))
    assert_template_result('   ', "{{ '1 1 1 1' | remove: 1 }}")

    assert_equal('b a a', @filters.remove_first("a b a a", 'a '))
    assert_template_result(' 1 1 1', "{{ '1 1 1 1' | remove_first: 1 }}")

    assert_equal('a a b', @filters.remove_last("a a b a", ' a'))
    assert_template_result('1 1 1 ', "{{ '1 1 1 1' | remove_last: 1 }}")
  end

  def test_pipes_in_string_arguments
    assert_template_result('foobar', "{{ 'foo|bar' | remove: '|' }}")
  end

  def test_strip
    assert_template_result('ab c', "{{ source | strip }}", { 'source' => " ab c  " })
    assert_template_result('ab c', "{{ source | strip }}", { 'source' => " \tab c  \n \t" })
  end

  def test_lstrip
    assert_template_result('ab c  ', "{{ source | lstrip }}", { 'source' => " ab c  " })
    assert_template_result("ab c  \n \t", "{{ source | lstrip }}", { 'source' => " \tab c  \n \t" })
  end

  def test_rstrip
    assert_template_result(" ab c", "{{ source | rstrip }}", { 'source' => " ab c  " })
    assert_template_result(" \tab c", "{{ source | rstrip }}", { 'source' => " \tab c  \n \t" })
  end

  def test_strip_newlines
    assert_template_result('abc', "{{ source | strip_newlines }}", { 'source' => "a\nb\nc" })
    assert_template_result('abc', "{{ source | strip_newlines }}", { 'source' => "a\r\nb\nc" })
  end

  def test_newlines_to_br
    assert_template_result("a<br />\nb<br />\nc", "{{ source | newline_to_br }}", { 'source' => "a\nb\nc" })
    assert_template_result("a<br />\nb<br />\nc", "{{ source | newline_to_br }}", { 'source' => "a\r\nb\nc" })
  end

  def test_plus
    assert_template_result("2", "{{ 1 | plus:1 }}")
    assert_template_result("2.0", "{{ '1' | plus:'1.0' }}")

    assert_template_result("5", "{{ price | plus:'2' }}", { 'price' => NumberLikeThing.new(3) })
  end

  def test_minus
    assert_template_result("4", "{{ input | minus:operand }}", { 'input' => 5, 'operand' => 1 })
    assert_template_result("2.3", "{{ '4.3' | minus:'2' }}")

    assert_template_result("5", "{{ price | minus:'2' }}", { 'price' => NumberLikeThing.new(7) })
  end

  def test_abs
    assert_template_result("17", "{{ 17 | abs }}")
    assert_template_result("17", "{{ -17 | abs }}")
    assert_template_result("17", "{{ '17' | abs }}")
    assert_template_result("17", "{{ '-17' | abs }}")
    assert_template_result("0", "{{ 0 | abs }}")
    assert_template_result("0", "{{ '0' | abs }}")
    assert_template_result("17.42", "{{ 17.42 | abs }}")
    assert_template_result("17.42", "{{ -17.42 | abs }}")
    assert_template_result("17.42", "{{ '17.42' | abs }}")
    assert_template_result("17.42", "{{ '-17.42' | abs }}")
  end

  def test_times
    assert_template_result("12", "{{ 3 | times:4 }}")
    assert_template_result("0", "{{ 'foo' | times:4 }}")
    assert_template_result("6", "{{ '2.1' | times:3 | replace: '.','-' | plus:0}}")
    assert_template_result("7.25", "{{ 0.0725 | times:100 }}")
    assert_template_result("-7.25", '{{ "-0.0725" | times:100 }}')
    assert_template_result("7.25", '{{ "-0.0725" | times: -100 }}')
    assert_template_result("4", "{{ price | times:2 }}", { 'price' => NumberLikeThing.new(2) })
  end

  def test_divided_by
    assert_template_result("4", "{{ 12 | divided_by:3 }}")
    assert_template_result("4", "{{ 14 | divided_by:3 }}")

    assert_template_result("5", "{{ 15 | divided_by:3 }}")
    assert_equal("Liquid error: divided by 0", Template.parse("{{ 5 | divided_by:0 }}").render)

    assert_template_result("0.5", "{{ 2.0 | divided_by:4 }}")
    assert_raises(Liquid::ZeroDivisionError) do
      assert_template_result("4", "{{ 1 | modulo: 0 }}")
    end

    assert_template_result("5", "{{ price | divided_by:2 }}", { 'price' => NumberLikeThing.new(10) })
  end

  def test_modulo
    assert_template_result("1", "{{ 3 | modulo:2 }}")
    assert_raises(Liquid::ZeroDivisionError) do
      assert_template_result("4", "{{ 1 | modulo: 0 }}")
    end

    assert_template_result("1", "{{ price | modulo:2 }}", { 'price' => NumberLikeThing.new(3) })
  end

  def test_round
    assert_template_result("5", "{{ input | round }}", { 'input' => 4.6 })
    assert_template_result("4", "{{ '4.3' | round }}")
    assert_template_result("4.56", "{{ input | round: 2 }}", { 'input' => 4.5612 })
    assert_raises(Liquid::FloatDomainError) do
      assert_template_result("4", "{{ 1.0 | divided_by: 0.0 | round }}")
    end

    assert_template_result("5", "{{ price | round }}", { 'price' => NumberLikeThing.new(4.6) })
    assert_template_result("4", "{{ price | round }}", { 'price' => NumberLikeThing.new(4.3) })
  end

  def test_ceil
    assert_template_result("5", "{{ input | ceil }}", { 'input' => 4.6 })
    assert_template_result("5", "{{ '4.3' | ceil }}")
    assert_raises(Liquid::FloatDomainError) do
      assert_template_result("4", "{{ 1.0 | divided_by: 0.0 | ceil }}")
    end

    assert_template_result("5", "{{ price | ceil }}", { 'price' => NumberLikeThing.new(4.6) })
  end

  def test_floor
    assert_template_result("4", "{{ input | floor }}", { 'input' => 4.6 })
    assert_template_result("4", "{{ '4.3' | floor }}")
    assert_raises(Liquid::FloatDomainError) do
      assert_template_result("4", "{{ 1.0 | divided_by: 0.0 | floor }}")
    end

    assert_template_result("5", "{{ price | floor }}", { 'price' => NumberLikeThing.new(5.4) })
  end

  def test_at_most
    assert_template_result("4", "{{ 5 | at_most:4 }}")
    assert_template_result("5", "{{ 5 | at_most:5 }}")
    assert_template_result("5", "{{ 5 | at_most:6 }}")

    assert_template_result("4.5", "{{ 4.5 | at_most:5 }}")
    assert_template_result("5", "{{ width | at_most:5 }}", { 'width' => NumberLikeThing.new(6) })
    assert_template_result("4", "{{ width | at_most:5 }}", { 'width' => NumberLikeThing.new(4) })
    assert_template_result("4", "{{ 5 | at_most: width }}", { 'width' => NumberLikeThing.new(4) })
  end

  def test_at_least
    assert_template_result("5", "{{ 5 | at_least:4 }}")
    assert_template_result("5", "{{ 5 | at_least:5 }}")
    assert_template_result("6", "{{ 5 | at_least:6 }}")

    assert_template_result("5", "{{ 4.5 | at_least:5 }}")
    assert_template_result("6", "{{ width | at_least:5 }}", { 'width' => NumberLikeThing.new(6) })
    assert_template_result("5", "{{ width | at_least:5 }}", { 'width' => NumberLikeThing.new(4) })
    assert_template_result("6", "{{ 5 | at_least: width }}", { 'width' => NumberLikeThing.new(6) })
  end

  def test_append
    assigns = { 'a' => 'bc', 'b' => 'd' }
    assert_template_result('bcd', "{{ a | append: 'd'}}", assigns)
    assert_template_result('bcd', "{{ a | append: b}}", assigns)
  end

  def test_concat
    assert_equal([1, 2, 3, 4], @filters.concat([1, 2], [3, 4]))
    assert_equal([1, 2, 'a'],  @filters.concat([1, 2], ['a']))
    assert_equal([1, 2, 10],   @filters.concat([1, 2], [10]))

    assert_raises(Liquid::ArgumentError, "concat filter requires an array argument") do
      @filters.concat([1, 2], 10)
    end
  end

  def test_prepend
    assigns = { 'a' => 'bc', 'b' => 'a' }
    assert_template_result('abc', "{{ a | prepend: 'a'}}", assigns)
    assert_template_result('abc', "{{ a | prepend: b}}", assigns)
  end

  def test_default
    assert_equal("foo", @filters.default("foo", "bar"))
    assert_equal("bar", @filters.default(nil, "bar"))
    assert_equal("bar", @filters.default("", "bar"))
    assert_equal("bar", @filters.default(false, "bar"))
    assert_equal("bar", @filters.default([], "bar"))
    assert_equal("bar", @filters.default({}, "bar"))
    assert_template_result('bar', "{{ false | default: 'bar' }}")
    assert_template_result('bar', "{{ drop | default: 'bar' }}", { 'drop' => BooleanDrop.new(false) })
    assert_template_result('Yay', "{{ drop | default: 'bar' }}", { 'drop' => BooleanDrop.new(true) })
  end

  def test_default_handle_false
    assert_equal("foo", @filters.default("foo", "bar", "allow_false" => true))
    assert_equal("bar", @filters.default(nil, "bar", "allow_false" => true))
    assert_equal("bar", @filters.default("", "bar", "allow_false" => true))
    assert_equal(false, @filters.default(false, "bar", "allow_false" => true))
    assert_equal("bar", @filters.default([], "bar", "allow_false" => true))
    assert_equal("bar", @filters.default({}, "bar", "allow_false" => true))
    assert_template_result('false', "{{ false | default: 'bar', allow_false: true }}")
    assert_template_result('Nay', "{{ drop | default: 'bar', allow_false: true }}", { 'drop' => BooleanDrop.new(false) })
    assert_template_result('Yay', "{{ drop | default: 'bar', allow_false: true }}", { 'drop' => BooleanDrop.new(true) })
  end

  def test_cannot_access_private_methods
    assert_template_result('a', "{{ 'a' | to_number }}")
  end

  def test_date_raises_nothing
    assert_template_result('', "{{ '' | date: '%D' }}")
    assert_template_result('abc', "{{ 'abc' | date: '%D' }}")
  end

  def test_reject
    array = [
      { "handle" => "alpha", "ok" => true },
      { "handle" => "beta", "ok" => false },
      { "handle" => "gamma", "ok" => false },
      { "handle" => "delta", "ok" => true },
    ]

    template = "{{ array | reject: 'ok' | map: 'handle' | join: ' ' }}"
    expected_output = "beta gamma"

    assert_template_result(expected_output, template, { "array" => array })
  end

  def test_reject_with_value
    array = [
      { "handle" => "alpha", "ok" => true },
      { "handle" => "beta", "ok" => false },
      { "handle" => "gamma", "ok" => false },
      { "handle" => "delta", "ok" => true },
    ]

    template = "{{ array | reject: 'ok', true | map: 'handle' | join: ' ' }}"
    expected_output = "beta gamma"

    assert_template_result(expected_output, template, { "array" => array })
  end

  def test_reject_with_false_value
    array = [
      { "handle" => "alpha", "ok" => true },
      { "handle" => "beta", "ok" => false },
      { "handle" => "gamma", "ok" => false },
      { "handle" => "delta", "ok" => true },
    ]

    template = "{{ array | reject: 'ok', false | map: 'handle' | join: ' ' }}"
    expected_output = "alpha delta"

    assert_template_result(expected_output, template, { "array" => array })
  end

  def test_has
    array = [
      { "handle" => "alpha", "ok" => true },
      { "handle" => "beta", "ok" => false },
      { "handle" => "gamma", "ok" => false },
      { "handle" => "delta", "ok" => false },
    ]

    expected_output = "true"

    assert_template_result(expected_output, "{{ array | has: 'ok' }}", { "array" => array })
    assert_template_result(expected_output, "{{ array | has: 'ok', true }}", { "array" => array })
  end

  def test_has_when_does_not_have_it
    array = [
      { "handle" => "alpha", "ok" => false },
      { "handle" => "beta", "ok" => false },
      { "handle" => "gamma", "ok" => false },
      { "handle" => "delta", "ok" => false },
    ]

    expected_output = "false"

    assert_template_result(expected_output, "{{ array | has: 'ok' }}", { "array" => array })
    assert_template_result(expected_output, "{{ array | has: 'ok', true }}", { "array" => array })
  end

  def test_has_with_empty_arrays
    template = <<~LIQUID
      {%- assign has_product = products | has: 'title.content', 'Not found' -%}
      {%- unless has_product -%}
        Product not found.
      {%- endunless -%}
    LIQUID
    expected_output = "Product not found."

    assert_template_result(expected_output, template, { "products" => [] })
  end

  def test_has_with_false_value
    array = [
      { "handle" => "alpha", "ok" => true },
      { "handle" => "beta", "ok" => false },
      { "handle" => "gamma", "ok" => false },
      { "handle" => "delta", "ok" => true },
    ]

    template = "{{ array | has: 'ok', false }}"
    expected_output = "true"

    assert_template_result(expected_output, template, { "array" => array })
  end

  def test_has_with_false_value_when_does_not_have_it
    array = [
      { "handle" => "alpha", "ok" => true },
      { "handle" => "beta", "ok" => true },
      { "handle" => "gamma", "ok" => true },
      { "handle" => "delta", "ok" => true },
    ]

    template = "{{ array | has: 'ok', false }}"
    expected_output = "false"

    assert_template_result(expected_output, template, { "array" => array })
  end

  def test_find_with_value
    products = [
      { "title" => "Pro goggles",    "price" => 1299 },
      { "title" => "Thermal gloves", "price" => 1499 },
      { "title" => "Alpine jacket",  "price" => 3999 },
      { "title" => "Mountain boots", "price" => 3899 },
      { "title" => "Safety helmet",  "price" => 1999 }
    ]

    template = <<~LIQUID
      {%- assign product = products | find: 'price', 3999 -%}
      {{- product.title -}}
    LIQUID
    expected_output = "Alpine jacket"

    assert_template_result(expected_output, template, { "products" => products })
  end

  def test_find_with_empty_arrays
    template = <<~LIQUID
      {%- assign product = products | find: 'title.content', 'Not found' -%}
      {%- unless product -%}
        Product not found.
      {%- endunless -%}
    LIQUID
    expected_output = "Product not found."

    assert_template_result(expected_output, template, { "products" => [] })
  end

  def test_find_index_with_value
    products = [
      { "title" => "Pro goggles",    "price" => 1299 },
      { "title" => "Thermal gloves", "price" => 1499 },
      { "title" => "Alpine jacket",  "price" => 3999 },
      { "title" => "Mountain boots", "price" => 3899 },
      { "title" => "Safety helmet",  "price" => 1999 }
    ]

    template = <<~LIQUID
      {%- assign index = products | find_index: 'price', 3999 -%}
      {{- index -}}
    LIQUID
    expected_output = "2"

    assert_template_result(expected_output, template, { "products" => products })
  end

  def test_find_index_with_empty_arrays
    template = <<~LIQUID
      {%- assign index = products | find_index: 'title.content', 'Not found' -%}
      {%- unless index -%}
        Index not found.
      {%- endunless -%}
    LIQUID
    expected_output = "Index not found."

    assert_template_result(expected_output, template, { "products" => [] })
  end

  def test_where
    array = [
      { "handle" => "alpha", "ok" => true },
      { "handle" => "beta", "ok" => false },
      { "handle" => "gamma", "ok" => false },
      { "handle" => "delta", "ok" => true },
    ]

    template = "{{ array | where: 'ok' | map: 'handle' | join: ' ' }}"
    expected_output = "alpha delta"

    assert_template_result(expected_output, template, { "array" => array })
  end

  def test_where_with_empty_string_is_a_no_op
    environment = { "array" => ["alpha", "beta", "gamma"] }
    expected_output = "alpha beta gamma"
    template = "{{ array | where: '' | join: ' ' }}"

    assert_template_result(expected_output, template, environment)
  end

  def test_where_with_nil_is_a_no_op
    environment = { "array" => ["alpha", "beta", "gamma"] }
    expected_output = "alpha beta gamma"
    template = "{{ array | where: nil | join: ' ' }}"

    assert_template_result(expected_output, template, environment)
  end

  def test_where_with_value
    array = [
      { "handle" => "alpha", "ok" => true },
      { "handle" => "beta", "ok" => false },
      { "handle" => "gamma", "ok" => false },
      { "handle" => "delta", "ok" => true },
    ]

    template = "{{ array | where: 'ok', true | map: 'handle' | join: ' ' }}"
    expected_output = "alpha delta"

    assert_template_result(expected_output, template, { "array" => array })
  end

  def test_where_with_false_value
    array = [
      { "handle" => "alpha", "ok" => true },
      { "handle" => "beta", "ok" => false },
      { "handle" => "gamma", "ok" => false },
      { "handle" => "delta", "ok" => true },
    ]

    template = "{{ array | where: 'ok', false | map: 'handle' | join: ' ' }}"
    expected_output = "beta gamma"

    assert_template_result(expected_output, template, { "array" => array })
  end

  def test_where_with_non_string_property
    array = [
      { "handle" => "alpha", "{}" => true },
      { "handle" => "beta", "{}" => false },
      { "handle" => "gamma", "{}" => false },
      { "handle" => "delta", "{}" => true },
    ]
    template = "{{ array | where: some_property, true | map: 'handle' | join: ' ' }}"
    expected_output = "alpha delta"

    assert_template_result(expected_output, template, { "array" => array, "some_property" => {} })
  end

  def test_where_string_keys
    input = [
      "alpha", "beta", "gamma", "delta"
    ]

    expectation = [
      "beta",
    ]

    assert_equal(expectation, @filters.where(input, "be"))
  end

  def test_where_no_key_set
    input = [
      { "handle" => "alpha", "ok" => true },
      { "handle" => "beta" },
      { "handle" => "gamma" },
      { "handle" => "delta", "ok" => true },
    ]

    expectation = [
      { "handle" => "alpha", "ok" => true },
      { "handle" => "delta", "ok" => true },
    ]

    assert_equal(expectation, @filters.where(input, "ok", true))
    assert_equal(expectation, @filters.where(input, "ok"))
  end

  def test_where_non_array_map_input
    assert_equal([{ "a" => "ok" }], @filters.where({ "a" => "ok" }, "a", "ok"))
    assert_equal([], @filters.where({ "a" => "not ok" }, "a", "ok"))
  end

  def test_where_indexable_but_non_map_value
    assert_raises(Liquid::ArgumentError) { @filters.where(1, "ok", true) }
    assert_raises(Liquid::ArgumentError) { @filters.where(1, "ok") }
  end

  def test_where_non_boolean_value
    input = [
      { "message" => "Bonjour!", "language" => "French" },
      { "message" => "Hello!", "language" => "English" },
      { "message" => "Hallo!", "language" => "German" },
    ]

    assert_equal([{ "message" => "Bonjour!", "language" => "French" }], @filters.where(input, "language", "French"))
    assert_equal([{ "message" => "Hallo!", "language" => "German" }], @filters.where(input, "language", "German"))
    assert_equal([{ "message" => "Hello!", "language" => "English" }], @filters.where(input, "language", "English"))
  end

  def test_where_array_of_only_unindexable_values
    assert_nil(@filters.where([nil], "ok", true))
    assert_nil(@filters.where([nil], "ok"))
  end

  def test_all_filters_never_raise_non_liquid_exception
    test_drop = TestDrop.new(value: "test")
    test_drop.context = Context.new
    test_enum = TestEnumerable.new
    test_enum.context = Context.new
    test_types = [
      "foo",
      123,
      0,
      0.0,
      -1234.003030303,
      -99999999,
      1234.38383000383830003838300,
      nil,
      true,
      false,
      TestThing.new,
      test_drop,
      test_enum,
      ["foo", "bar"],
      { "foo" => "bar" },
      { foo: "bar" },
      [{ "foo" => "bar" }, { "foo" => 123 }, { "foo" => nil }, { "foo" => true }, { "foo" => ["foo", "bar"] }],
      { 1 => "bar" },
      ["foo", 123, nil, true, false, Drop, ["foo"], { foo: "bar" }],
    ]
    StandardFilters.public_instance_methods(false).each do |method|
      arg_count = @filters.method(method).arity
      arg_count *= -1 if arg_count < 0

      test_types.repeated_permutation(arg_count) do |args|
        @filters.send(method, *args)
      rescue Liquid::Error
        nil
      end
    end
  end

  def test_where_no_target_value
    input = [
      { "foo" => false },
      { "foo" => true },
      { "foo" => "for sure" },
      { "bar" => true },
    ]

    assert_equal([{ "foo" => true }, { "foo" => "for sure" }], @filters.where(input, "foo"))
  end

  def test_sum_with_all_numbers
    input = [1, 2]

    assert_equal(3, @filters.sum(input))
    assert_raises(Liquid::ArgumentError, "cannot select the property 'quantity'") do
      @filters.sum(input, "quantity")
    end
  end

  def test_sum_with_numeric_strings
    input = [1, 2, "3", "4"]

    assert_equal(10, @filters.sum(input))
    assert_raises(Liquid::ArgumentError, "cannot select the property 'quantity'") do
      @filters.sum(input, "quantity")
    end
  end

  def test_sum_with_nested_arrays
    input = [1, [2, [3, 4]]]

    assert_equal(10, @filters.sum(input))
    assert_raises(Liquid::ArgumentError, "cannot select the property 'quantity'") do
      @filters.sum(input, "quantity")
    end
  end

  def test_sum_with_indexable_map_values
    input = [{ "quantity" => 1 }, { "quantity" => 2, "weight" => 3 }, { "weight" => 4 }]

    assert_equal(0, @filters.sum(input))
    assert_equal(3, @filters.sum(input, "quantity"))
    assert_equal(7, @filters.sum(input, "weight"))
    assert_equal(0, @filters.sum(input, "subtotal"))
  end

  def test_sum_with_indexable_non_map_values
    input = [1, [2], "foo", { "quantity" => 3 }]

    assert_equal(3, @filters.sum(input))
    assert_raises(Liquid::ArgumentError, "cannot select the property 'quantity'") do
      @filters.sum(input, "quantity")
    end
  end

  def test_sum_with_unindexable_values
    input = [1, true, nil, { "quantity" => 2 }]

    assert_equal(1, @filters.sum(input))
    assert_raises(Liquid::ArgumentError, "cannot select the property 'quantity'") do
      @filters.sum(input, "quantity")
    end
  end

  def test_sum_without_property_calls_to_liquid
    t = TestThing.new
    Liquid::Template.parse('{{ foo | sum }}').render("foo" => [t])
    assert(t.foo > 0)
  end

  def test_sum_with_property_calls_to_liquid_on_property_values
    t = TestThing.new
    Liquid::Template.parse('{{ foo | sum: "quantity" }}').render("foo" => [{ "quantity" => t }])
    assert(t.foo > 0)
  end

  def test_sum_of_floats
    input = [0.1, 0.2, 0.3]
    assert_equal(0.6, @filters.sum(input))
    assert_template_result("0.6", "{{ input | sum }}", { "input" => input })
  end

  def test_sum_of_negative_floats
    input = [0.1, 0.2, -0.3]
    assert_equal(0.0, @filters.sum(input))
    assert_template_result("0.0", "{{ input | sum }}", { "input" => input })
  end

  def test_sum_with_float_strings
    input = [0.1, "0.2", "0.3"]
    assert_equal(0.6, @filters.sum(input))
    assert_template_result("0.6", "{{ input | sum }}", { "input" => input })
  end

  def test_sum_resulting_in_negative_float
    input = [0.1, -0.2, -0.3]
    assert_equal(-0.4, @filters.sum(input))
    assert_template_result("-0.4", "{{ input | sum }}", { "input" => input })
  end

  def test_sum_with_floats_and_indexable_map_values
    input = [{ "quantity" => 1 }, { "quantity" => 0.2, "weight" => -0.3 }, { "weight" => 0.4 }]
    assert_equal(0.0, @filters.sum(input))
    assert_equal(1.2, @filters.sum(input, "quantity"))
    assert_equal(0.1, @filters.sum(input, "weight"))
    assert_equal(0.0, @filters.sum(input, "subtotal"))
    assert_template_result("0", "{{ input | sum }}", { "input" => input })
    assert_template_result("1.2", "{{ input | sum: 'quantity' }}", { "input" => input })
    assert_template_result("0.1", "{{ input | sum: 'weight' }}", { "input" => input })
    assert_template_result("0", "{{ input | sum: 'subtotal' }}", { "input" => input })
  end

  def test_sum_with_non_string_property
    input = [{ "true" => 1 }, { "1.0" => 0.2, "1" => -0.3 }, { "1..5" => 0.4 }]

    assert_equal(1, @filters.sum(input, true))
    assert_equal(0.2, @filters.sum(input, 1.0))
    assert_equal(-0.3, @filters.sum(input, 1))
    assert_equal(0.4, @filters.sum(input, (1..5)))
    assert_equal(0, @filters.sum(input, nil))
    assert_equal(0, @filters.sum(input, ""))
  end

  def test_uniq_with_to_liquid_value
    input = [StringDrop.new("foo"), StringDrop.new("bar"), "foo"]
    expected = [StringDrop.new("foo"), StringDrop.new("bar")]
    result = @filters.uniq(input)

    assert_equal(expected, result)
  end

  def test_uniq_with_to_liquid_value_pick_correct_classes
    input = ["foo", StringDrop.new("foo"), StringDrop.new("bar")]
    expected = [String, StringDrop]
    result = @filters.uniq(input).map(&:class)

    assert_equal(expected, result)
  end

  private

  def with_timezone(tz)
    old_tz    = ENV['TZ']
    ENV['TZ'] = tz
    yield
  ensure
    ENV['TZ'] = old_tz
  end
end # StandardFiltersTest
