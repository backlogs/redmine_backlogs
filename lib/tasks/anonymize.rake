desc "Anonymize your database -- DON'T USE THIS UNLESS YOU REALLY, REALLY KNOW WHAT YOU'RE DOING. NOT KIDDING HERE!"

$count = {}
def random_string(model_attr, v)
  return '' if v.nil? &&  model_attr.match(/\.mail/)
  return nil if v.nil?

  $count[model_attr] ||= 0
  $count[model_attr] += 1
  nv = "#{model_attr}#{$count[model_attr]}"
  nv << "@example.com" if model_attr.match(/\.mail/)
  return nv
end

namespace :redmine do
  namespace :backlogs do
    task :anonymize => :environment do
      if ENV['ANONYMIZE'] != 'yes'
        puts "This will anonymize ALL YOUR DATA"
        puts "ARE YOU VERY, VERY SURE?"
        puts "If so, type 'Yes!' (case matters!)"

        answer = STDIN.gets.chomp
        exit if answer != "Yes!"
      end

      clear = ['AuthSource', 'AuthSourceLdap', 'Message', 'News', 'Comment', 'Changeset', 'Document', 'Attachment', 'Board', 'Change']
      ignore = [
        'AnonymousUser#language',
        'Group#language',
        'AnonymousUser#login',
        'CustomField#field_format',
        'CustomField#regexp',
        'EnabledModule#',
        'Enumeration#name',
        'JournalDetail#',
        'Principal#language',
        'Principal#mail_notification',
        'Project#identifier',
        'Query#column_names',
        'Query#filters',
        'Query#group_by',
        'Query#sort_criteria',
        'RbIssueHistory#',
        'RbSprintBurndown#',
        'RbRelease#sharing',
        'RbRelease#status',
        'RbReleaseBurndownCache#',
        'Role#',
        'Setting#',
        'Tracker#name',
        'User#language',
        'UserPreference#',
        'Version#sharing',
        'Version#status',
        'WikiContent::Version#compression',
      ]

      admins = []
      Rails.application.eager_load!
      ActiveRecord::Base.descendants.sort{|a, b| a.name <=> b.name}.each do |model|
        if clear.include?(model.name)
          puts "Deleting all #{model.name.pluralize}"
          model.delete_all
          next
        end

        attrs = []
        model.columns_hash.each_pair { |attrib, column|
          #next unless model.content_columns.include?(column)
          next if column.name == 'type'
          next if attrib.match(/_type$/)
          next if [:integer, :boolean, :datetime, :date, :float].include?(column.type)
          if ignore.include?("#{model.name}##{attrib}") || ignore.include?("#{model.name}#")
            puts "Ignoring #{model.name}##{attrib}"
            next
          end

          attrs << attrib
        }

        if attrs.size != 0
          attrs.sort!
          puts "Anonymizing #{model.name} (#{attrs.join(',')})..."

          model.all.each { |obj|
            vals = {}
            attrs.each{|k|
              "#{model.name}##{k}"
              vals[k] = random_string("#{model.name}.#{k}", obj.send(k))
            }
            model.update_all(vals, ['id=?', obj.id])
          }
        end
      end

      Issue.update_all({:due_date => nil}, ['not due_date is null and not start_date is null and due_date < start_date'])
      Member.update_all(:mail_notification => false)
      User.update_all(:auth_source_id => nil, :mail_notification => '',
                      :hashed_password => '5f2570b6183a74c5709a751ad344a909436f16f5', :salt => 'e358ba6a9fd7e24796b149315e8554a4',
                      :identity_url => nil)

      puts "Your anonymized admins are #{User.where(['admin = ?', true]).collect{|u| u.login}.inspect} with password 'insecure'"
    end
  end
end
