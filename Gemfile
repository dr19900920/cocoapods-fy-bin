SKIP_UNRELEASED_VERSIONS = false

# Specify your gem's dependencies in cocoapods-fy-bin.gemspec


def cp_gem(name, repo_name, branch = 'master', path: false)
  return gem name if SKIP_UNRELEASED_VERSIONS
  opts = if path
           { :path => "../#{repo_name}" }
         else
           url = "https://github.com/CocoaPods/#{repo_name}.git"
           { :git => url, :branch => branch }
         end
  gem name, opts
end

source 'https://rubygems.org'


group :development do

  cp_gem 'cocoapods',                'cocoapods', path: 'CocoaPods'
  cp_gem 'xcodeproj',                'xcodeproj', path: 'Xcodeproj'
  cp_gem 'cocoapods-fy-bin',                'cocoapods-fy-bin', path: 'cocoapods-fy-bin'

  gem 'cocoapods-generate', '~>2.0.1'
  gem 'mocha'
  gem 'bacon'
  gem 'mocha-on-bacon'
  gem 'prettybacon'

end
