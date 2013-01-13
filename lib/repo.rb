require 'ruhoh'
require 'ruhoh/programs/compile'

class Repo
  attr_accessor :owner_name, :name, :domain

  # These regex's are supposed to follow GitHub's allowed naming strategy.

  # alphanumeric + dash but cannot start with dash.
  OwnerRegex = /^[a-zA-Z\d]{1}[a-zA-Z\d\-]+$/
  # alphanumeric + dash + underscore + period
  NameRegex = /^[\w\-\.]+$/

  TmpPath     = '/tmp'
  RepoPath    = File.expand_path(File.join('~', 'repos'))
  TargetPath  = File.expand_path(File.join('~', 'www'))
  LogPath     = File.expand_path(File.join('~', 'user-logs'))
  
  # @param[Hash] payload the webhook provider payload object.
  def initialize(payload=nil)
    # this check is ad-hoc and can obviously be gamed.
    if (payload['git_url'].include?('github.com') rescue false)
      parse_github(payload)
    end
  end
  
  # Try full deploy
  def try_deploy
    return log("ERROR: Invalid #{@provider} Payload") unless valid?
    return log("ERROR: Could not update Git repository") unless update
    deploy
  end

  # Update the repository from origin (GitHub).
  # If we don't have the repo OR the repo is not mergeable with origin, we clone new.
  # Else we can fetch and merge.
  #
  # Notes: 
  #   merge-base will return the common ancestor sha1 of the two branches.
  #   no ancestor means the branches are not mergeable.
  def update
    return clone unless File.exist? File.join(repo_path, '.git')

    FileUtils.cd(repo_path) {
      system('git', 'fetch', 'origin')

      if `git merge-base origin/master master`.empty?
        return clone 
      else
        return system('git', 'reset', '--hard', 'origin/master')
      end
    }
  end
  
  def deploy
    FileUtils.cd(repo_path) {
      # compile ruhoh 2.0
      ruhoh = Ruhoh.new
      ruhoh.setup(log_file: log_path)
      ruhoh.env = 'production'
      ruhoh.setup_paths
      ruhoh.paths.compiled = tmp_path
      ruhoh.compile

      FileUtils.mkdir_p target_path
      unless system('rsync', '-az', '--stats', '--delete', "#{tmp_path}/.", target_path)
        log("ERROR: Compiled blog failed to rysnc to www directory. This is a system error and has been reported!")
        return false
      end
      FileUtils.rm_r(tmp_path) if File.exist?(tmp_path)
      
      handle_domain_mapping
    }
    
    log("SUCCESS: Blog compiled and deployed.")
    true
    
  # This is a standard exit from Ruhoh.log.error which has already been addressed.
  # Most typically due to invalid blog configuration.
  rescue SystemExit
    false
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
    File.join(RepoPath, full_name)
  end
  
  def tmp_path
    File.join(TmpPath, site_name)
  end
  
  # Where this repo will compile its website to
  def target_path
    File.join(TargetPath, site_name)
  end
  
  def log_path
    File.join(LogPath, "#{site_name}.txt")
  end
  
  def log(message)
    FileUtils.mkdir_p File.dirname(log_path)
    File.open(log_path, "a") { |f|
      f.puts '---'
      f.puts Time.now.utc
      f.puts message
    }
  end

  protected
  
  Providers = ["github"]
  
  def parse_github(payload)
    @provider = "github"
    @owner_name = payload['repository']['owner']['name'] rescue nil
    @name       = payload['repository']['name'] rescue nil
  end

  # git clone the repository from GitHub even if we have an existing repo
  # as it may be out of sync with the origin.
  def clone
    if FileTest.directory? repo_path
      fresh_clone = "#{repo_path}-fresh"
      return false unless system('git', 'clone', git_url, fresh_clone)
    
      FileUtils.rm_r repo_path
      FileUtils.mv fresh_clone, repo_path
    else
      return system('git', 'clone', git_url, repo_path)
    end
  end

  # Do not trust user submitted input tee.hee
  def valid?
    return false unless @owner_name =~ OwnerRegex
    return false unless @name =~ NameRegex
    true
  end

  # symbolically link a mapped domain to the canonical directory
  def handle_domain_mapping
    return false unless @custom_domain
    FileUtils.symlink(target_path, File.join(TargetPath, @custom_domain))
  end

end