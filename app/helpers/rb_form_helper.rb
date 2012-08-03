module RbFormHelper
  unloadable

  def rb_form_for(*args, &proc)
    form_string = form_for(*args, &proc)
    if Rails::VERSION::MAJOR < 3
      form_string
    else
      concat(form_string)
    end
  end

  # Streamline the difference between <%=  %> and <%  %>
  def rb_labelled_fields_for(*args, &proc)
    fields_string = labelled_fields_for(*args, &proc)
    if Rails::VERSION::MAJOR < 3
      fields_string
    else
      concat(fields_string)
    end
  end

  # Streamline the difference between <%=  %> and <%  %>
  def rb_labelled_form_for(*args, &proc)
    form_string = labelled_form_for(*args, &proc)
    if Rails::VERSION::MAJOR < 3
      form_string
    else
      concat(form_string)
    end
  end

end
