class User
  attr_reader :payload, :uid, :nickname, :email, :name

  def initialize(github_auth)
    @payload = github_auth
    @uid = github_auth['uid']
    @nickname = github_auth['info']['nickname']
    @email = github_auth['info']['email']
    @name = github_auth['info']['name']
  end
  
  def avatar_url
    self.payload['extra']['raw_info']['avatar_url']
  end
  
end