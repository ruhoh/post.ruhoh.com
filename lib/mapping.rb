class Mapping
  
  attr_accessor :username, :domain, :is_saved

  def initialize(username)
    self.username = username
    data = DB.db.get_first_row("select * from mappings where username = ?", username)
    if data
      self.domain = data[1]
      self.is_saved = true
    end
  end
  
  def save
    if self.is_saved
      DB.db.execute "UPDATE mappings SET domain = ?  WHERE username = ?", self.domain, self.username
    else
      DB.db.execute "INSERT INTO mappings VALUES ( ?, ? )", self.username, self.domain
      self.is_saved = true
    end
    self
  end
  
end