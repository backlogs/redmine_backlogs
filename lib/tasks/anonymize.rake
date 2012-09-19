desc "Anonymize your database -- DON'T USE THIS UNLESS YOU REALLY, REALLY KNOW WHAT YOU'RE DOING. NOT KIDDING HERE!"

$ALPHANUMERICS = [('0'..'9'),('A'..'Z'),('a'..'z')].map {|range| range.to_a}.flatten
$PASSWORD = ((0... 8).map { $ALPHANUMERICS[rand($ALPHANUMERICS.size)] }.join)

$count = {}
def random_string(model_attr, v)
  return nil if !v

  $count[model_attr] ||= 0
  $count[model_attr] += 1
  nv = "#{model_attr}#{$count[model_attr]}"
  nv << "@example.com" if model_attr.match(/\.mail/)
  return nv
end

namespace :redmine do
  namespace :backlogs do
    task :anonymize => :environment do
      puts "This will anonymize ALL YOUR DATA"
      puts "ARE YOU VERY, VERY SURE?"
      puts "If so, type 'Yes!' (case matters!)"

      answer = STDIN.gets.chomp
      return if answer != "Yes!"

      Issue.update_all({:due_date => nil}, ['not due_date is null and not start_date is null and due_date < start_date'])
      Member.update_all(:mail_notification => false)
      User.update_all(:mail_notification => '')

      ignore = [
        'AnonymousUser#language',
        'Version#status',
        'Version#sharing',
        'CustomField#regexp',
        'CustomField#field_format',
        'Principal#language',
        'JournalDetail#property',
        'JournalDetail#prop_key',
        'Query#column_names',
        'Query#group_by',
        'Query#sort_criteria',
        'Query#filters',
        'Enumeration#name',
        'WikiContent::Version#compression',
        'User#language',
        'AnonymousUser#login',
        'Setting#',
        'Principal#mail_notification'
      ]

      admins = []
      ActiveRecord::Base.send(:subclasses).each do |model|
        attrs = []
        model.columns_hash.each_pair { |attrib, column|
          #next unless model.content_columns.include?(column)
          next if column.name == 'type'
          next if attrib.match(/_type$/)
          next if [:integer, :boolean, :datetime, :date, :float].include?(column.type)
          next if ignore.include?("#{model.name}##{attrib}") || ignore.include?("#{model.name}#")

          attrs << attrib
        }

        if attrs.size != 0
          puts "Anonymizing #{model.name} (#{attrs.join(',')})..."
          model.all.each { |obj|
            vals = {}
            attrs.each{|k|
              "#{model.name}##{k}"
              vals[k] = random_string("#{model.name}.#{k}", obj.send(k))
            }
            model.update_all(vals, ['id=?', obj.id])

            if model.name == 'Principal' && obj.admin?
              admins << obj.login
            end
          }
        end
      end

      User.find(:all).each { |user|
        user.password = $PASSWORD
        user.save!
      }

      puts "Your anonymized admins are #{admins.inspect} with password '#{$PASSWORD}'"
    end
  end
end
