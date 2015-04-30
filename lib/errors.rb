module Backup
  class InternalError < StandardError

  end
  class ConfigError < InternalError
    
  end
  class DatabaseError < InternalError
    
  end
  class ValidationError < StandardError

  end
end
