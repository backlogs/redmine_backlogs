module RbMasterBacklogsHelper
  unloadable
  include Redmine::I18n

  def backlog_menu(is_sprint, items = [])
    html = %{
      <div class="menu">
        <div class="icon ui-icon ui-icon-carat-1-s"></div>
        <ul class="items">
    }
    items.each do |item|
      item[:condition] = true if item[:condition].blank?
      if item[:condition] && ( (is_sprint && item[:for] == :sprint) ||
                               (!is_sprint && item[:for] == :product) ||
                               (item[:for] == :both) )
        html += %{ <li class="item">#{item[:item]}</li> }
      end
    end
    html += %{
        </ul>
      </div>
    }
  end

  def menu_link(label, options = {})
    # options[:class] = "pureCssMenui"
    link_to(label, options)
  end
end
