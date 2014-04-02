# Weechat-url-hinter

Weechat url hinter is a plugin that open a url on weehcat buffer without touching mouse.

This plugin is available in only Mac OSX.

# Requirement

* Weechat (with ruby)

# Installation

Url hinter is not still registered as an official script in http://www.weechat.org/scripts/ .
You can't install from `/script install` command now, so please execute follow command in
your terminal.

```console
$ curl -o ~/.weechat/ruby/autoload/url_hinter.rb https://raw.githubusercontent.com/tkengo/weechat-url-hinter/master/weechat-url-hinter.rb
```

And then, restart weechat.

# Usage

1. Type '/url_hinter' command on the input buffer of Weechat.
2. Then, this plugin searches url strings such as 'http://...' or 'https://...'
3. If urls are found, they are highlighted and give hint key to the url.
4. When you type a hint key, open the url related to hint key in your default browser.
