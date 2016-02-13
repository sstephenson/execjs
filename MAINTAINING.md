# Maintaining

## Releasing a new version

This project follows [semver](http://semver.org/). So if you are making a bug
fix, only increment the patch level "2.0.x". If any new files are added, a minor
version "2.x.x" bump is in order.

### Make a release commit

To prepare the release commit, edit the
[lib/execjs/version.rb](https://github.com/rails/execjs/blob/master/lib/execjs/version.rb)
`VERSION` value. Then make a single commit with the description as
"ExecJS 2.x.x". Finally, tag the commit with `v2.x.x`.

```
$ git pull
$ vim ./lib/execjs/version.rb
$ git add ./lib/execjs/version.rb
$ git ci -m "ExecJS 2.x.x"
$ rake release
```
