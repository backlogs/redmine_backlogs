module Backlogs
  module ActiveRecord
    def batch_modify_attributes(attribs)
      attribs.each_pair{|k, v|
        # I can't find any damn combination of safe_attributes that works
        next if ['parent_id', 'rgt', 'lft'].include?(k)

        begin
          self.send("#{k}=", v)
        rescue => e
          puts "#{e} for #{k} = #{v}"
        end
      }
    end

    def batch_update_attributes!(attribs)
      self.batch_modify_attributes(attribs)
      return self.save!
    end
    def journalized_batch_update_attributes!(attribs)
      self.init_journal(User.current)
      return self.batch_update_attributes!(attribs)
    end
    def batch_update_attributes(attribs)
      self.batch_modify_attributes(attribs)
      return self.save
    end
    def journalized_batch_update_attributes(attribs)
      self.init_journal(User.current)
      return self.batch_update_attributes(attribs)
    end
    def journalized_update_attribute(attrib, v)
      self.init_journal(User.current)
      return self.update_attribute(attrib, v)
    end
  end
end
