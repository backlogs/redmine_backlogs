module RbPartialsHelper
  unloadable

  PLUGIN_VIEWS_PATH = File.expand_path('../../views', __FILE__)

  class << self

    def def_erb_method(method_name_and_args, filename)
      erb_data = File.read(filename)
      eruby = Erubis::FastEruby.new(erb_data)
      eruby.def_method(self, method_name_and_args)
      method_name = method_name_and_args[/^[^(]+/].strip
      alias_method "_erb_of_#{method_name}", method_name
      define_method method_name do |*args|
        public_send("_erb_of_#{method_name}", *args).html_safe
      end
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

