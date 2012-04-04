require 'ruhoh'
require 'ruhoh/compiler'

class Repo
  TmpPath     = '/tmp'
  RepoPath    = File.expand_path(File.join('~', 'repos'))
  TargetPath  = File.expand_path(File.join('~', 'www'))

  def initialize(github_payload)
    @payload = github_payload
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
    "#{@payload['repository']['owner']['name']}.ruhoh.com"
  end

  # Full name is the repository owner + repository name
  # This will uniquely define all repos on GitHub
  def full_name
    "#{@payload['repository']['owner']['name']}-#{@payload['repository']['name']}"
  end
  
  # The git_url is the full name to the repository.
  # Users are encouraged to set the webhook for the repo: username.ruhoh.com
  # but really any repo that has the webhook will run.
  def git_url
    "git://github.com/#{@payload['repository']['owner']['name']}/#{@payload['repository']['name']}.git"
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
  
  def valid_payload?
    return false unless (@payload && @payload['repository'] && @payload['repository']['name'] && @payload['repository']['owner'] && @payload['repository']['owner']['name'])
    return false if @payload['repository']['owner']['name'].empty?
    return false if @payload['repository']['name'].empty?
    true
  end
  
end #Repo