require 'ruhoh'
require 'ruhoh/programs/compile'

class Repo
  attr_accessor :user, :name, :custom_domain, :provider, :branch
  attr_reader :error

  # These regex's are supposed to follow GitHub's allowed naming strategy.

  # alphanumeric + dash but cannot start with dash.
  OwnerRegex = /^[a-zA-Z\d]{1}[a-zA-Z\d\-]+$/
  # alphanumeric + dash + underscore + period
  NameRegex = /^[\w\-\.]+$/

  TmpPath     = '/tmp'
  RepoPath    = File.expand_path(File.join('~', 'repos'))
  TargetPath  = File.expand_path(File.join('~', 'www'))
  LogPath     = File.expand_path(File.join('~', 'user-logs'))
  
  def initialize
    @_frozen_snapshot = {}
    @error = "There was a problem!"
    @branch = 'master'
  end
  
  def self.all(constraints)
    r = Parse::Query.new("Repo")
    r.where = constraints
    r.get
  end
  
  def self.dictionary(constraints)
    dict = {}
    repos = all(constraints)
    repos.each { |r| dict[r["name"]] = r }
    dict
  end

  # Find or build a repo instance with the provided constraint attributes.
  # Internally queries the persistance storage (currently Parse).
  # @_persistor object is stored to avoid duplicate database entries.
  #
  # @param[Hash] constraints
  #
  def self.find_or_build(constraints)
    obj = all(constraints)[0] || Parse::Object.new("Repo", constraints)
    repo = new
    repo.store(obj)
    repo.user = obj['user']
    repo.name = obj['name']
    repo.custom_domain = obj['domain']
    repo
  end
  
  # Find or build a repo instance from an incoming payload.
  # Payload providers are handled internally.
  # @param[Hash] payload from a service provider.
  def self.find_or_build_with_payload(payload)
    # this check is ad-hoc and can obviously be gamed.
    if (payload['git_url'].include?('github.com') rescue false)
      load_from_github_payload(payload)
    else
      message = "Payload does not appear to be from GitHub"
      log(message)
      abort(message)
    end
  end
  
  def save
    # Validate the domain:
    if persistor['domain'] && persistor['domain'] =~ /.ruhoh.com$/i
      unless persistor['domain'].downcase.start_with?(persistor["user"].downcase)
        @error = "ruhoh based domains must start with your username"
        return false
      end
    end
    
    result = persistor.save

    # onchange callbacks (probably a better way to do this)
    
    if @_frozen_snapshot['domain'] && (persistor['domain'] != @_frozen_snapshot['domain'])
      # delete the old symlink
      old_symlink = File.join(TargetPath, @_frozen_snapshot['domain'])
      FileUtils.rm old_symlink if File.symlink?(old_symlink)
    end
    
    result
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
  #
  # @return[Boolean] was the update successful?
  def update
    return clone unless File.exist? File.join(repo_path, '.git')

    FileUtils.cd(repo_path) {
      system('git', 'fetch', 'origin')
      return system('git', 'reset', '--hard', "origin/#{@branch}")
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
    @error = "Ruhoh failed to compile your repo. Please check the logs."
    false
  rescue Exception => e
    log(e)
    @error = e
    false
  end
  
  #
  def domain
    if @name.downcase == "#{@user}.ruhoh.com".downcase
      "#{@user}.ruhoh.com".downcase
    else
      "#{full_name}.ruhoh.com".downcase
    end
  end

  # Full name is the repository owner + repository name
  # This will uniquely define all repos on GitHub
  def full_name
    "#{@user}-#{@name}"
  end
  
  # The git_url is the full name to the repository.
  # Users are encouraged to set the webhook for the repo: username.ruhoh.com
  # but really any repo that has the webhook will run.
  def git_url
    "git://github.com/#{@user}/#{@name}.git"
  end
  
  # This repos git directory
  def repo_path
    File.join(RepoPath, full_name)
  end
  
  def tmp_path
    File.join(TmpPath, domain)
  end
  
  # Where this repo will compile its website to
  def target_path
    File.join(TargetPath, domain)
  end
  
  def log_path
    File.join(LogPath, "#{domain}.txt")
  end
  
  def log(message)
    FileUtils.mkdir_p File.dirname(log_path)
    File.open(log_path, "a") { |f|
      f.puts '---'
      f.puts Time.now.utc
      f.puts message
    }
  end

  def store(obj)
    @_persistor = obj
    @_frozen_snapshot = obj.dup.freeze
  end

  protected

  # git clone the repository from GitHub even if we have an existing repo
  # as it may be out of sync with the origin.
  def clone
    if FileTest.directory? repo_path
      fresh_clone = "#{repo_path}-fresh"

      unless system('git', 'clone', git_url, fresh_clone)
        @error = "Could not `git clone #{git_url}`"
        return false
      end

      FileUtils.rm_r repo_path
      FileUtils.mv fresh_clone, repo_path
    else
      return system('git', 'clone', git_url, repo_path)
    end
  end

  # Do not trust user submitted input tee.hee
  def valid?
    return false unless @user =~ OwnerRegex
    return false unless @name =~ NameRegex
    true
  end

  # symbolically link a mapped domain to the canonical directory
  def handle_domain_mapping
    return false unless @custom_domain
    custom_path = File.join(TargetPath, @custom_domain)
    return false if target_path == custom_path
    
    FileUtils.symlink(target_path, custom_path)
  end
  
  # the internal persistance object
  # Kind of messy but eh =/
  def persistor
    @_persistor ||= Parse::Object.new("Repo")
    @_persistor["user"] = user
    @_persistor["name"] = name
    @_persistor["domain"] = custom_domain
    @_persistor
  end
  
  # Extract relevant information from GitHub payload
  # and normalize it for instantiated repo object.
  def self.load_from_github_payload(payload)
    user = payload['repository']['owner']['name'] rescue nil
    name = payload['repository']['name'] rescue nil
    log("User not found") and abort("User not found") unless user
    log("Name not found") and abort("Name not found") unless name

    repo = find_or_build({
      "user" => user,
      "name" => name,
    })
    repo.provider = "github"
    repo
  end

end