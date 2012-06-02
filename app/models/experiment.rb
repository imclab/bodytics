class Experiment < ActiveRecord::Base
    has_many :conditions, :dependent => :destroy
end
