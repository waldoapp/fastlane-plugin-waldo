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
for the most critical flows in your app. This plugin provides a `waldo` action
which allows you to upload an iOS build to Waldo for processing.

## Usage

To get started, first obtain an API key and an application ID from Waldo for
your app. These are used to authenticate with the Waldo backend on each call.

These are the same credentials that you added in your `waldo.yml` configuration file during the onboarding.

Next, build a new IPA for your app. If you use `gym` (aka `build_ios_app`) to
build your IPA, `waldo` will automatically find and upload the generated
IPA.

```ruby
gym
waldo(api_key: "0123456789abcdef0123456789abcdef",
      application_id: "app-0123456789abcdef")
```

> **Note:** You _must_ specify the Waldo API key and application ID key.

If for some reason you do _not_ use `gym` to build your IPA, you will need to
explicitly specify the IPA path to `waldo`:

```ruby
waldo(ipa_path: "/path/to/YourApp.ipa",
      api_key: "0123456789abcdef0123456789abcdef",
      application_id: "app-0123456789abcdef")
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
