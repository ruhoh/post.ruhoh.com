require 'ruhoh'
require 'ruhoh/compiler'

class Repo
  attr_reader :owner_name, :name
  
  # These regex's are supposed to follow GitHub's allowed naming strategy.

  # alphanumeric + dash but cannot start with dash.
  OwnerRegex = /^[a-zA-Z\d]{1}[a-zA-Z\d\-]+$/
  # alphanumeric + dash + underscore + period
  NameRegex = /^[\w\-\.]+$/

  TmpPath     = '/tmp'
  RepoPath    = File.expand_path(File.join('~', 'repos'))
  TargetPath  = File.expand_path(File.join('~', 'www'))
  LogPath     = File.expand_path(File.join('~', 'user-logs'))

  def initialize(github_payload)
    self.parse_payload(github_payload)
  end
  
  # Try full deploy
  def try_deploy
    return self.log("ERROR: Invalid GitHub Payload") unless self.valid?
    return self.log("ERROR: Could not update Git repository") unless self.update
    self.deploy
  end

  # Update the repository from origin (GitHub).
  # If we don't have the repo OR the repo is not mergeable with origin, we clone new.
  # Else we can fetch and merge.
  #
  # Notes: 
  #   merge-base will return the common ancestor sha1 of the two branches.
  #   no ancestor means the branches are not mergeable.
  def update
    return self.clone unless File.exist? File.join(self.repo_path, '.git')

    FileUtils.cd(self.repo_path) {
      system('git', 'fetch', 'origin')

      if `git merge-base origin/master master`.empty?
        return self.clone 
      else
        return system('git', 'reset', '--hard', 'origin/master')
      end
    }
  end
  
  # git clone the repository from GitHub even if we have an existing repo
  # as it may be out of sync with the origin.
  def clone
    if FileTest.directory? self.repo_path
      fresh_clone = "#{self.repo_path}-fresh"
      return false unless system('git', 'clone', self.git_url, fresh_clone)
    
      FileUtils.rm_r self.repo_path
      FileUtils.mv fresh_clone, self.repo_path
    else
      return system('git', 'clone', self.git_url, self.repo_path)
    end
  end
  
  def deploy
    FileUtils.cd(self.repo_path) {
      # compile
      Ruhoh.setup(log_file: self.log_path)
      Ruhoh.config.env = 'production'
      Ruhoh.setup_paths
      Ruhoh.setup_urls
      # no plugin support on post.ruhoh.com
      Ruhoh::DB.update_all
      Ruhoh::Compiler.compile(self.tmp_path)

      # move to www directory
      FileUtils.mkdir_p self.target_path
      unless system('rsync', '-az', '--stats', '--delete', "#{self.tmp_path}/.", self.target_path)
        self.log("ERROR: Compiled blog failed to rysnc to www directory. This is a system error and has been reported!")
        return false
      end
      FileUtils.rm_r(self.tmp_path) if File.exist?(self.tmp_path)
      
      # symbolically link a mapped domain to the canonical directory
      mapping = Mapping.new(self.owner_name)
      if mapping && mapping.domain
        FileUtils.symlink(self.target_path, File.join(TargetPath, mapping.domain))
      end
    }
    
    self.log("SUCCESS: Blog compiled and deployed.")
    true
    
  # This is a standard exit from Ruhoh.log.error which has already been addressed.
  # Most typically due to invalid blog configuration.
  rescue SystemExit
    false
  end
  
  def log(message)
    FileUtils.mkdir_p File.dirname(self.log_path)
    File.open(self.log_path, "a") { |f|
      f.puts '---'
      f.puts Time.now.utc
      f.puts message
    }
  end
  
  # Currently all repos from a given GitHub user will be attached to only the user's username.
  # In other words a user only gets one static website in ruhoh for now:
  # username.ruhoh.com
  # NOTE: All repos that post to the users endpoint will update the same site for now:
  def site_name
    "#{@owner_name}.ruhoh.com".downcase
  end

  # Full name is the repository owner + repository name
  # This will uniquely define all repos on GitHub
  def full_name
    "#{@owner_name}-#{@name}"
  end
  
  # The git_url is the full name to the repository.
  # Users are encouraged to set the webhook for the repo: username.ruhoh.com
  # but really any repo that has the webhook will run.
  def git_url
    "git://github.com/#{@owner_name}/#{@name}.git"
  end
  
  # This repos git directory
  def repo_path
    File.join(RepoPath, self.full_name)
  end
  
  def tmp_path
    File.join(TmpPath, self.site_name)
  end
  
  # Where this repo will compile its website to
  def target_path
    File.join(TargetPath, self.site_name)
  end
  
  def log_path
    File.join(LogPath, "#{self.site_name}.txt")
  end
  
  def parse_payload(github_payload)
    @owner_name = github_payload['repository']['owner']['name'] rescue nil
    @name       = github_payload['repository']['name'] rescue nil
  end
  
  # Do not trust user submitted input tee.hee
  def valid?
    return false unless @owner_name =~ OwnerRegex
    return false unless @name =~ NameRegex
    true
  end
  
end #Repo