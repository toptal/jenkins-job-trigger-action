# frozen_string_literal: true

task default: :git_release

task :git_release do
  version = `cat VERSION`
  `git add VERSION`
  `git commit -m "Version bump to #{version}"`
  `git push origin master`
  `git tag -a -m "Tagging version #{version}" #{version}`
  `git push origin #{version}`
end
