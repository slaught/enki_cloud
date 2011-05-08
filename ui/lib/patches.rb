
#http://opensoul.org/2007/2/7/validations-on-empty-not-nil-attributes
#Validations on empty (not nil) attributes
#One of the first problems that I ran into when I started using Rails was
#trying to validate the format of attributes that aren’t required. Most of the
#validations have an :allow_nil option, but the problem is that when a form is
#submitted with empty form fields, those fields are empty strings instead of
#nil values. So the validation fails because the attribute is not nil.
#
#For example, here’s a Person model with a validation on
#:social_security_number, an optional attribute:
#
#class Person < ActiveRecord::Base
#  validates_format_of :social_security_number,
#    :with => /\d{3}[-]?\d{2}[-]?\d{4}/, :allow_nil => true
#end
#
#When this model is used in a form, validation will fail if the social security
#number field is left blank, even though :allow_nil is set to true.
#
#
#The solution
#
#It turns out that the solution is really simple: a before_validation callback
#that just goes through and sets all the empty attributes to nil.
#


class  ActiveRecord::Base
#  before_validation :clear_empty_attrs
  protected
  def clear_empty_attrs
    @attributes.each do |key,value|
      self[key] = nil if (!value.equal?(false) && value.blank?)
    end
  end
end


