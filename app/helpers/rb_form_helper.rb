module RbFormHelper
  unloadable

  def rb_form_for(*args, &proc)
    form_string = form_for(*args, &proc)
    concat(form_string)
  end

  # Streamline the difference between <%=  %> and <%  %>
  def rb_labelled_fields_for(*args, &proc)
    fields_string = labelled_fields_for(*args, &proc)
    concat(fields_string)
  end

  # Streamline the difference between <%=  %> and <%  %>
  def rb_labelled_form_for(*args, &proc)
    form_string = labelled_form_for(*args, &proc)
    concat(form_string)
  end

end
