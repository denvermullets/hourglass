module StubbingHelper
  # Temporarily replace `klass.method_name` with a block that returns
  # `return_value`, and restore the original after the yielded block runs.
  #
  # Used to stub class methods (e.g., service `.call`) without pulling in
  # mocha. `Object#stub` from Minitest::Mock isn't available on classes
  # in Minitest 6.x.
  def with_stubbed_class_method(klass, method_name, return_value)
    sclass = klass.singleton_class
    alias_target = :"_stubbed_orig_#{method_name}"
    sclass.alias_method(alias_target, method_name)
    klass.define_singleton_method(method_name) { |*_a, **_k| return_value }
    yield
  ensure
    sclass.alias_method(method_name, alias_target)
    sclass.send(:remove_method, alias_target)
  end
end
