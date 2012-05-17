source :rubygems

gemspec

group :test do
  gem 'json'
  # see https://github.com/jbarnette/johnson/issues/21
  gem 'johnson',      :platform => :mri_18
  # see https://github.com/nu7hatch/mustang/issues/18
  gem 'mustang',      :platform => :ruby,
    :git => "https://github.com/nu7hatch/mustang.git", :ref => "2a3bcfbd9fd0f34e9b004fcd92188f326b40ec2a"
  # disabled for rbx, because of https://github.com/cowboyd/therubyracer/issues/157
  gem 'therubyracer', :platform => :mri
  gem 'therubyrhino', ">=1.73.3", :platform => :jruby
end
