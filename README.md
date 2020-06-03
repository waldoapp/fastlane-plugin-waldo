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
which allows you to upload an iOS or Android build to Waldo for processing.

## Usage

To get started, first obtain an upload token from Waldo for your app. These are
used to authenticate with the Waldo backend on each call.

### Uploading an iOS Simulator Build

Create a new simulator build for your app.

You can use `gym` (aka `build_ios_app`) to build your app provided that you
supply several parameters in order to convince Xcode to _both_ build for the
simulator _and_ not attempt to generate an IPA:

```ruby
gym(configuration: 'Release',
    derived_data_path: '/path/to/derivedData',
    skip_package_ipa: true,
    skip_archive: true,
    destination: 'generic/platform=iOS Simulator')
```

You can then find your app (and associated symbols) relative to the derived
data path:

```ruby
app_path = File.join(derived_data_path,
                     'Build',
                     'Products',
                     'ReleaseSim-iphonesimulator',
                     'YourApp.app')
```

Regardless of how you create the actual simulator build for your app, the
upload itself is very simple:

```ruby
waldo(upload_token: '0123456789abcdef0123456789abcdef',
      app_path: '/path/to/YourApp.app',
      include_symbols: true)
```

> **Note:** You _must_ specify _both_ the Waldo upload token _and_ the path of
> the `.app`. The `include_symbols` parameter is optional but we highly
> recommend supplying it.

### Uploading an iOS Device Build

Build a new IPA for your app. If you use `gym` (aka `build_ios_app`) to build
your IPA, `waldo` will automatically find and upload the generated IPA.

```ruby
gym(export_method: 'ad-hoc')                            # or 'development'

waldo(upload_token: '0123456789abcdef0123456789abcdef',
      dsym_path: lane_context[SharedValues::DSYM_OUTPUT_PATH])
```

> **Note:** You _must_ specify the Waldo upload token. The `dsym_path`
> parameter is optional but we highly recommend supplying it.

If you do _not_ use `gym` to build your IPA, you will need to explicitly
specify the IPA path to `waldo`:

```ruby
waldo(upload_token: '0123456789abcdef0123456789abcdef',
      ipa_path: '/path/to/YourApp.ipa',
      dsym_path: '/path/to/YourApp.app.dSYM.zip')
```

### Uploading an Android Build

Build a new APK for your app. If you use `gradle` to build your APK, `waldo`
will automatically find and upload the generated APK.

```ruby
gradle(task: 'assemble',
       build_type: 'Release')

waldo(upload_token: '0123456789abcdef0123456789abcdef')
```

> **Note:** You _must_ specify the Waldo upload token.

If you do _not_ use `gradle` to build your APK, you will need to explicitly
specify the APK path to `waldo`:

```ruby
waldo(upload_token: '0123456789abcdef0123456789abcdef',
      apk_path: '/path/to/YourApp.apk')
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
