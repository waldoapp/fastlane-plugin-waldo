# Waldo `fastlane` plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-waldo)

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To
get started with `fastlane-plugin-waldo`, add it to your project by running:

```bash
fastlane add_plugin waldo
```

## About Waldo

[Waldo](https://www.waldo.io) provides fast, reliable, and maintainable tests
for the most critical flows in your app. This plugin provides a `waldo_upload`
action which allows you to upload an iOS app binary to the Waldo backend for
processing.

## Usage

To get started, first obtain an application identifier and an API key in Waldo.
These are used to authenticate with the Waldo API in each call.

```ruby
waldo_upload(
  app_path: '/Users/jgp/Desktop/XestiMonitorsDemo.ipa',
  application_id: 'app-b6ef42d5f619357b',
  api_key: '9191623f3d80780c391be39085ed2652',
  package_name: 'com.xesticode.XestiMonitorsDemo-iOS',
  variant_name: 'ad-hoc'
)
```

## Example

Check out the [example `Fastfile`](fastlane/Fastfile) to see how to use this plugin. Try it by cloning the repo, running `fastlane install_plugins` and `bundle exec fastlane test`.

**Note to author:** Please set up a sample project to make it easy for users to explore what your plugin does. Provide everything that is necessary to try out the plugin in this project (including a sample Xcode/Android project if necessary)

## Run tests for this plugin

To run both the tests, and code style validation, run

```
rake
```

To automatically fix many of the styling issues, use
```
rubocop -a
```

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).
