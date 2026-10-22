# SuwayomiiOS

Native SwiftUI iOS client for a [Suwayomi](https://github.com/Suwayomi/Suwayomi-Server) server.
Mihon extensions are Android APKs and cannot run on iOS, so the server runs them and this app talks to its GraphQL API.

Implemented: server setup (basic auth), library grid, chapter list, paged reader, mark-as-read.
Not yet: browse/search sources, categories, downloads, tracking, reading-direction options.

Build (macOS): `brew install xcodegen && xcodegen && open SuwayomiiOS.xcodeproj`.
This was written without access to a Swift toolchain and has not been compiled.
