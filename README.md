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
action which allows you to upload an iOS build to Waldo for processing.

## Usage

To get started, first obtain an application ID and an API key from Waldo for
your app. These are used to authenticate with the Waldo backend on each call.

Next, build a new IPA for your app. If you use `gym` (aka `build_ios_app`) to
build your IPA, `waldo_upload` will automatically find and upload the generated
IPA.

```ruby
gym
waldo_upload
```

When called without parameters, `waldo_upload` uses the default Waldo
configuration path (`./.waldo.yml`) to obtain the application ID and API key
for authentication. You can also specify the Waldo configuration path
explicitly:

```ruby
gym
waldo_upload(configuration_path: "/path/to/YourWaldoConfig.yml")
```

You can even specify the application ID and API key directly on `waldo_upload`:

```ruby
gym
waldo_upload(api_key: "0123456789abcdef0123456789abcdef",
             application_id: "app-0123456789abcdef")
```

This is typically _not_ recommended for reasons of security.

Finally, if you do _not_ use `gym` to build your IPA, you will need to
explicitly specify the IPA path to `waldo_upload`:

```ruby
waldo_upload(ipa_path: "/path/to/YourApp.ipa")
```

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this
repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins
Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/)
guide.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out
the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for
your iOS and Android apps. To learn more, check out
[fastlane.tools](https://fastlane.tools).
