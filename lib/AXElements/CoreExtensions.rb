require 'active_support/inflector'


# Overrides for the Array class that makes it possible to
module ArrayAXElementExtensions

  # If the array contains {AX::Element} objects, then we can just
  # iterate over the array passing the argument in.
  #
  # You have to be careful in cases where the array contains various
  # types of {AX::Element} objects that may not have the same
  # attributes or you could end up having a single element throw
  # a {NoMethodError}.
  def method_missing method, *args
    return super        unless first.kind_of? AX::Element
    return map(&method) if AX::Element.method_map[method]
    map &(singularized_method_name method)
  end


  private

  # Takes a method name and singularizes it, including the case where
  # the method name is a predicate.
  # @param [Symbol] method
  # @return [Symbol]
  def singularized_method_name method
    method = method.to_s
    if method.predicate?
      (method[0...-1].singularize + '?').to_sym
    else
      method.singularize.to_sym
    end
  end

end


# Monkey patches on top of Array
class Array
  include ArrayAXElementExtensions
end


# Extensions to the String class.
class String

  # Returns the upper camel case version of the string. The string
  # is assumed to be in snake_case, but should return an unchanged
  # string if the string is already in camel case.
  #
  # I chose to make this method update the string in place as it
  # is a fairly hot method and should perform well; by running in
  # place we save an allocation (which is slow on MacRuby right now).
  # @return [String]
  def camelize!
    gsub! /(?:^|_)(.)/ do $1.upcase end
  end

  # Tells you if the symbol would be a predicate method by
  # checking if it ends with a question mark '?'.
  def predicate?
    match( /\?$/ ) != nil
  end

end
