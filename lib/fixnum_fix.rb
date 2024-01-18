# Override Fixnum to Integer cause Everote client is ancient.
if !defined?(Fixnum)
  Fixnum = Integer
end
