module BacklogsPlugin
  module Hooks
    class LayoutHook < Redmine::Hook::ViewListener
      # this ought to be view_issues_sidebar_queries_bottom, but
      # the entire queries toolbar is disabled if you don't have
      # custom queries

      def exception(context, ex)
        context[:controller].send(:flash)[:error] = "Backlogs error: #{ex.message} (#{ex.class})"
        RAILS_DEFAULT_LOGGER.error "#{ex.message} (#{ex.class}): " + ex.backtrace.join("\n")
      end

      def view_issues_sidebar_planning_bottom(context={ })
        begin
          project = context[:project]
  
          return '' unless project && !project.blank?
          return '' unless Backlogs.configured?(project)
  
          sprint_id = nil
  
          params = context[:controller].params
          case "#{params['controller']}##{params['action']}"
            when 'issues#show'
              if params['id'] && (issue = Issue.find(params['id'])) && (issue.is_task? || issue.is_story?) && issue.fixed_version
                sprint_id = issue.fixed_version_id
              end
  
            when 'issues#index'
              q = context[:request].session[:query]
              sprint = (q && q[:filters]) ? q[:filters]['fixed_version_id'] : nil
              if sprint && sprint[:operator] == '=' && sprint[:values].size == 1
                sprint_id = sprint[:values][0]
              end
          end
  
          url_options = {
            :only_path  => false,
            :controller => :rb_hooks_render,
            :action     => :view_issues_sidebar,
            :project_id => project.identifier,
            :host => context[:request].host_with_port,
            :protocol => context[:request].ssl? ? 'https' : 'http'
          }
          url_options[:sprint_id] = sprint_id if sprint_id
  
          # Why can't I access protect_against_forgery?
          return %{
            <div id="backlogs_view_issues_sidebar"></div>
            <script type="text/javascript">
              jQuery(document).ready(function() {
                jQuery('#backlogs_view_issues_sidebar').load('#{url_for(url_options)}');
              });
            </script>
          }
        rescue => e
          exception(context, e)
          return ''
        end
      end

      def view_issues_show_details_bottom(context={ })
        begin
          issue = context[:issue]
  
          return '' unless Backlogs.configured?(issue.project)
  
          snippet = ''
  
          project = context[:project]
  
          if issue.is_story?
            snippet += "<tr><th>#{l(:field_story_points)}</th><td>#{RbStory.find(issue.id).points_display}</td></tr>"
            vbe = issue.velocity_based_estimate
            snippet += "<tr><th>#{l(:field_velocity_based_estimate)}</th><td>#{vbe ? vbe.to_s + ' days' : '-'}</td></tr>"
          end
  
          if issue.is_task? && User.current.allowed_to?(:update_remaining_hours, project) != nil
            snippet += "<tr><th>#{l(:field_remaining_hours)}</th><td>#{issue.remaining_hours}</td></tr>"
          end
  
          return snippet
        rescue => e
          exception(context, e)
          return ''
        end
      end

      def view_issues_form_details_bottom(context={ })
        begin
          snippet = ''
          issue = context[:issue]
  
          return '' unless Backlogs.configured?(issue.project)
  
          #project = context[:project]
  
          #developers = project.members.select {|m| m.user.allowed_to?(:log_time, project)}.collect{|m| m.user}
          #developers = select_tag("time_entry[user_id]", options_from_collection_for_select(developers, :id, :name, User.current.id))
          #developers = developers.gsub(/\n/, '')
  
          if issue.is_story?
            snippet += '<p>'
            #snippet += context[:form].label(:story_points)
            snippet += context[:form].text_field(:story_points, :size => 3)
            snippet += '</p>'
  
            if issue.descendants.length != 0 && !issue.new_record?
              snippet += javascript_include_tag 'jquery/jquery-1.6.2.min.js', :plugin => 'redmine_backlogs'
              snippet += <<-generatedscript
  
                <script type="text/javascript">
                  var $j = jQuery.noConflict();
  
                  $j(document).ready(function() {
                    $j('#issue_estimated_hours').attr('disabled', 'disabled');
                    $j('#issue_done_ratio').attr('disabled', 'disabled');
                    $j('#issue_start_date').parent().hide();
                    $j('#issue_due_date').parent().hide();
                  });
                </script>
              generatedscript
            end
          end
  
          params = context[:controller].params
          if issue.is_story? && params[:copy_from]
            snippet += "<p><label for='link_to_original'>#{l(:rb_label_link_to_original)}</label>"
            snippet += "#{check_box_tag('link_to_original', params[:copy_from], true)}</p>"
  
            snippet += "<p><label>#{l(:rb_label_copy_tasks)}</label>"
            snippet += "#{radio_button_tag('copy_tasks', 'open:' + params[:copy_from], true)} #{l(:rb_label_copy_tasks_open)}<br />"
            snippet += "#{radio_button_tag('copy_tasks', 'none', false)} #{l(:rb_label_copy_tasks_none)}<br />"
            snippet += "#{radio_button_tag('copy_tasks', 'all:' + params[:copy_from], false)} #{l(:rb_label_copy_tasks_all)}</p>"
          end
  
          if issue.is_task? && !issue.new_record?
            snippet += "<p><label for='remaining_hours'>#{l(:field_remaining_hours)}</label>"
            snippet += text_field_tag('remaining_hours', issue.remaining_hours, :size => 3)
            snippet += '</p>'
          end
  
          return snippet
        rescue => e
          exception(context, e)
          return ''
        end
      end

      def view_versions_show_bottom(context={ })
        begin
          version = context[:version]
          project = version.project
  
          return '' unless Backlogs.configured?(project)
  
          snippet = ''
  
          if User.current.allowed_to?(:edit_wiki_pages, project)
            snippet += '<span id="edit_wiki_page_action">'
            snippet += link_to l(:button_edit_wiki), {:controller => 'rb_wikis', :action => 'edit', :project_id => project.id, :sprint_id => version.id }, :class => 'icon icon-edit'
            snippet += '</span>'
  
            # this wouldn't be necesary if the schedules plugin
            # didn't disable the contextual hook
            snippet += javascript_include_tag 'jquery/jquery-1.6.2.min.js', :plugin => 'redmine_backlogs'
            snippet += <<-generatedscript
  
              <script type="text/javascript">
                  var $j = jQuery.noConflict();
                $j(document).ready(function() {
                  $j('#edit_wiki_page_action').detach().appendTo("div.contextual");
                });
              </script>
            generatedscript
          end
        rescue => e
          exception(context, e)
          return ''
        end
      end

      def view_my_account(context={ })
        begin
          return %{
            <h3>#{l(:label_backlogs)}</h3>
            <div class="box tabular">
            <p>
              #{label :backlogs, :task_color}
              #{text_field :backlogs, :task_color, :value => context[:user].backlogs_preference[:task_color]}
            </p>
            </div>
          }
        rescue => e
          exception(context, e)
          return ''
        end
      end

      def controller_issues_new_after_save(context={ })
        params = context[:params]
        issue = context[:issue]

        return unless Backlogs.configured?(issue.project)

        if issue.is_story?
          if params[:link_to_original]
            rel = IssueRelation.new

            rel.issue_from_id = Integer(params[:link_to_original])
            rel.issue_to_id = issue.id
            rel.relation_type = IssueRelation::TYPE_RELATES
            rel.save
          end

          if params[:copy_tasks] =~ /^[a-z]+:[0-9]+$/
            action, id = *(params[:copy_tasks].split(/:/))

            story = RbStory.find(Integer(id))

            if action != 'none'
              case action
                when 'open'
                  tasks = story.tasks.select{|t| !t.reload.closed?}
                when 'none'
                  tasks = []
                when 'all'
                  tasks = story.tasks
                else
                  raise "Unexpected value #{params[:copy_tasks]}"
              end

              tasks.each {|t|
                nt = RbTask.new
                nt.copy_from(t)
                nt.parent_issue_id = issue.id
                nt.save!
              }
            end
          end
        end
      end

      def controller_issues_edit_after_save(context={ })
        params = context[:params]
        issue = context[:issue]

        if issue.is_task?
          begin
            issue.remaining_hours = Float(params[:remaining_hours])
          rescue ArgumentError, TypeError
            issue.remaining_hours = nil
          end
          issue.save
        end
      end

      def view_layouts_base_html_head(context={})
        return '' if Setting.login_required? && !User.current.logged?

        if User.current.admin? && !context[:request].session[:backlogs_configured]
          context[:request].session[:backlogs] = Backlogs.configured?
          context[:controller].send(:flash)[:error] = l(:label_backlogs_unconfigured) if !context[:request].session[:backlogs]
        end

        return %{
          <link rel="stylesheet" href="#{Engines::RailsExtensions::AssetHelpers.plugin_asset_path('redmine_backlogs', 'javascripts', 'jquery/jquery.jqplot/jquery.jqplot.min.css')}" type="text/css" />

          #{javascript_include_tag 'jquery/jquery-1.6.2.min.js', :plugin => 'redmine_backlogs'}
          #{javascript_include_tag 'jquery/jquery-ui-1.8.16.custom.min.js', :plugin => 'redmine_backlogs'}

          #{javascript_include_tag 'jquery/jquery.jeditable.mini.js', :plugin => 'redmine_backlogs'}
          #{javascript_include_tag 'jquery/jquery.scrollfollow.js' ,:plugin => 'redmine_backlogs'}

          <!--[if IE]>#{javascript_include_tag 'jquery/jquery.jqplot/excanvas.js', :plugin => 'redmine_backlogs'}<![endif]-->
          #{javascript_include_tag 'jquery/jquery.jqplot/jquery.jqplot.js', :plugin => 'redmine_backlogs'}
          #{javascript_include_tag 'jquery/jquery.jqplot/plugins/jqplot.highlighter.js', :plugin => 'redmine_backlogs'}
          #{javascript_include_tag 'jquery/jquery.jqplot/plugins/jqplot.canvasTextRenderer.min.js', :plugin => 'redmine_backlogs'}
          #{javascript_include_tag 'jquery/jquery.jqplot/plugins/jqplot.canvasAxisTickRenderer.min.js', :plugin => 'redmine_backlogs'}
          #{javascript_include_tag 'jquery/jquery.jqplot/plugins/jqplot.enhancedLegendRenderer.min.js', :plugin => 'redmine_backlogs'}

          #{javascript_include_tag 'jquery/jquery.cookie.js' ,:plugin => 'redmine_backlogs'}

          <script type="text/javascript" src="#{url_for(:controller => 'rb_all_projects', :action => 'server_variables')}"></script>
          #{javascript_include_tag 'common.js', 'burndown.js', :plugin => 'redmine_backlogs'}
        }
      end

      def view_timelog_edit_form_bottom(context={ })
        time_entry = context[:time_entry]
        return '' if time_entry[:issue_id].blank?

        issue = Issue.find(context[:time_entry].issue_id)
        return '' unless Backlogs.configured?(issue.project) &&
                         Backlogs.setting[:timelog_from_taskboard]=='enabled'
        snippet=''

        begin
          if issue.is_task? && User.current.allowed_to?(:update_remaining_hours, time_entry.project) != nil
            remaining_hours = issue.remaining_hours
            snippet += "<p><label for='remaining_hours'>#{l(:field_remaining_hours)}</label>"
            snippet += text_field_tag('remaining_hours', remaining_hours, :size => 6)
            snippet += '</p>'
          end
          return snippet
        rescue => e
          exception(context, e)
          return ''
        end

      end       

      def controller_timelog_edit_before_save(context={ })
        time_entry = context[:time_entry]
        return '' if time_entry[:issue_id].blank?

        params = context[:params]
        return unless params.include?("commit")

        issue = Issue.find(time_entry.issue_id)
        return unless Backlogs.configured?(issue.project) &&
                      Backlogs.setting[:timelog_from_taskboard]=='enabled'

        if issue.is_task? && User.current.allowed_to?(:update_remaining_hours, time_entry.project) != nil
          remaining_hours = params[:remaining_hours].gsub(',','.').to_f
          if remaining_hours != issue.remaining_hours
            if time_entry.save
              issue.journalized_update_attribute(:remaining_hours,remaining_hours)
              issue.remaining_hours = remaining_hours
              issue.save
            end
          end
        end
      end

    end
  end
end
