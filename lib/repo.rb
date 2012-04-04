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

  def initialize(github_payload)
    self.parse_payload(github_payload)
  end
  
  def update
    if File.exist? File.join(self.repo_path, '.git')
      return FileUtils.cd(self.repo_path) {
        return system('git', 'pull', 'origin', 'master')
      }
    else
      FileUtils.mkdir_p self.repo_path
      return system('git', 'clone', self.git_url, self.repo_path)
    end
  end
  
  # TODO: Make sure to properly handle errors when compiling.
  def deploy
    FileUtils.cd(self.repo_path) {
      Ruhoh.setup
      Ruhoh::Compiler.new(self.tmp_path).compile
      
      FileUtils.mkdir_p self.target_path
      system('rsync', '-az', '--stats', '--delete', "#{self.tmp_path}/.", self.target_path)
      FileUtils.rm_r(self.tmp_path) if File.exist?(self.tmp_path)
    }
  end
  
  # Currently all repos from a given GitHub user will be attached to only the user's username.
  # In other words a user only gets one static website in ruhoh for now:
  # username.ruhoh.com
  # NOTE: All repos that post to the users endpoint will update the same site for now:
  def site_name
    "#{@owner_name}.ruhoh.com"
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