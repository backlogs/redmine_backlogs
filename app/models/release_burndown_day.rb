class ReleaseBurndownDay < ActiveRecord::Base
    unloadable
    belongs_to :release

end
