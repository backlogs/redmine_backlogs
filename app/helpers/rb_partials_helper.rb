module RbPartialsHelper
  unloadable

  PLUGIN_VIEWS_PATH = File.expand_path('../../views', __FILE__)

  class << self

    def def_erb_method(method_name_and_args, filename)
      erb_data = File.read(filename)
      eruby = Erubis::FastEruby.new(erb_data)
      eruby.def_method(self, method_name_and_args)
      method_name = method_name_and_args[/^[^(]+/].strip.to_sym
      define_method "#{method_name}_with_html_safe" do |*args, &block|
        send("#{method_name}_without_html_safe", *args, &block).html_safe
      end
      alias_method_chain method_name, :html_safe
      method_name
    end

    def def_rb_partial_method(method_name_and_args, rb_partial_filename)
      filename = File.expand_path(rb_partial_filename, PLUGIN_VIEWS_PATH)
      def_erb_method(method_name_and_args, filename)
    end

  end


  def_rb_partial_method 'render_rb_task(task)', 'rb_tasks/_task.html.erb'

  def render_rb_task_collection(tasks)
    capture do
      tasks.each do |task|
        concat render_rb_task(task)
      end
    end
  end

end

