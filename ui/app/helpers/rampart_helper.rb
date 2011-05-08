module RampartHelper
  def template_options
    options = RampartServiceTemplate.all.collect{|t| [t.description, t.id]}.sort_by{|elem| elem[0]}
    options << ['Custom...', -1]
    options
  end
end
