source 'https://rubygems.org'

gemspec

group :test do
  gem 'json'
  gem 'therubyrhino', ">=1.73.3", :platform => :jruby
  if Object.const_defined?(:RUBY_ENGINE) && RUBY_ENGINE == 'rbx'
    gem 'libv8', "~> 3.11.8"
    gem 'therubyracer', :git => 'https://github.com/cowboyd/therubyracer.git', :ref => 'a318291c5af64fe117ee09d6c2615f3c0b9b2080'
  else
    gem 'therubyracer', :platform => :mri
  end
end
