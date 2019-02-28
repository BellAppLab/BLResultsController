Pod::Spec.new do |s|

  s.name                = "BLResultsController"
  s.version             = "1.0.1"
  s.summary             = "BLResultsController is not a drop-in replacement for the `NSFetchedResultsController` to be used with Realm."
  s.screenshot          = "https://github.com/BellAppLab/BLResultsController/raw/master/Images/BLResultsController.png"

  s.description         = <<-DESC
Contrary to popular belief, BLResultsController is **not** a drop-in replacement for the `NSFetchedResultsController` to be used with Realm. Oh no. It's _better_.

A `ResultsController` takes a `Realm.Results` and divides its objects into sections based on the `sectionNameKeyPath` and the first `sortDescriptor`. It then calculates the relative positions of those objects and generates section indices and `IndexPath`s that are ready to be passed to `UITableView`s and `UICollectionView`s.

But **no expensive calculations are made on the main thread**. That's right. Everything is done in the background, so your UI will remain as smooth and responsive as always.

As with `Realm.Results`, the `ResultsController` is a live, auto-updating container that will keep notifying you of changes in the dataset for as long as you hold a strong reference to it. You register to receive those changes by calling `setChangeCallback(_:)` on your controller.

Changes to the underlying dataset are calculated on a background queue, therefore the UI thread is not impacted by the `ResultsController`'s overhead.

**Note**: As with `Realm` itself, the `ResultsController` is **not** thread-safe. You should only call most of its methods from the main thread.

## Features

- [X] Calculates everything on a **background thread**. 🏎
- [X] No objects are retained, so memory footprint is minimal. 👾
- [X] Calculates section index titles. 😲
- [X] Allows for user-initiated search. 🕵️‍♀️🕵️‍♂️
- [X] Most methods return in O(1). 😎
- [X] Well documented. 🤓
- [X] Well tested. 👩‍🔬👨‍🔬
                   DESC

  s.homepage            = "https://github.com/BellAppLab/BLResultsController"

  s.license             = { :type => "MIT", :file => "LICENSE" }

  s.author              = { "Bell App Lab" => "apps@bellapplab.com" }
  s.social_media_url    = "https://twitter.com/BellAppLab"

  s.ios.deployment_target = "9.0"
  s.osx.deployment_target = "10.10"
  s.tvos.deployment_target = "10.0"

  s.module_name         = 'BLResultsController'

  s.source              = { :git => "https://github.com/BellAppLab/BLResultsController.git", :tag => "#{s.version}" }

  s.source_files        = "BLResultsController"

  s.framework           = "Foundation"
  s.ios.framework       = 'UIKit'
  s.osx.framework       = 'AppKit'
  s.tvos.framework      = 'UIKit'

  s.dependency          'RealmSwift', '~> 3.0'
  s.dependency          'BackgroundRealm', '~> 1.0'

  s.swift_version       = "4.2"

end
