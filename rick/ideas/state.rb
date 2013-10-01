
  state_def :status, { 
        :basket => { :quoting },
        :quoting => { :quoting_error, :quoted },
        :quoted => { :in_progress, :canceled },
        :in_progress => { :error, :canceled, :complete},
        }

 yields

  class Status
    def self.new(*states) 

    end
    self.flag_map
  end
