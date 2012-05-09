## post.ruhoh.com

This is a tiny sinatra app that accepts POSTS from a GitHub repository (enabled by webhooks).

## Contributing

Currently this only supports git and GitHub but there's no reason it can't be expanded to support
other VCS and services.

If you are familiar with other services such as bitbucket, please hack the hell out of `lib/repo.rb`
to make it work with these other services. It's fine if it doesn't merge nicely, the important part is to
get the logic properly encapsulated in the methods.

In other words, there are very simple methods that make this app work:

- parse\_payload
- update
- clone
- deploy

Feel free to replace these with VCS/service specific implementations and we'll sort out the details.

## Run locally

````bash
$ bundle install
$ bundle exec rackup -p 3000
````

To emulate an incoming POST request, you can use the provided rake task:

````bash
$ bundle exec rake post
````

This rake task uses `test/github-post-receive.json` as its payload. 
Feel free to overwrite the variables here, namely:

````ruby
github_payload['repository']['owner']['name']
github_payload['repository']['name']
````

## How it works

The meat of the application is on lib/repo.rb
Please study this file to figure out how the process works.

Also, there's a bunch of omniauth GitHub stuff that I thought I needed but don't.
This app doesn't need them _currently_ so feel free to ignore it all.

Remember that this app will be writing to your localhost. 
The default paths are configured in `lib/repo.rb`

````ruby
TmpPath     = '/tmp'
RepoPath    = File.expand_path(File.join('~', 'repos'))
TargetPath  = File.expand_path(File.join('~', 'www'))
LogPath     = File.expand_path(File.join('~', 'user-logs'))
````

Change these paths to suit your own needs when working in development.

Any questions, feel free to email, tweet, etc.

## License 

MIT as always!

