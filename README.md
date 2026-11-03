# Riqing (日轻)

> An unofficial open-source derivative maintained on top of **MewX's Wenku8 project**.

**Current Android version: 0.5.5+2286 (ARM64)**

## What this fork does

Riqing keeps the Wenku8 0.5.5 reading and local-library experience while restoring and reorganizing online reading into a maintainable multi-source architecture. It includes online discovery/search/detail/TOC/chapter flows, independent source sessions, custom sources, current Wenku8 domain compatibility, and adapters for additional supported sites.

Third-party websites can change their domains, APIs, login systems, or page structures at any time, so permanent availability of every source cannot be guaranteed.

## Update channel

Starting with **v2286**, in-app updates check only this repository's GitHub Releases:

`486Subaru/Wenku8_Flutter_Online`

Riqing no longer checks `mikufoxxx/Wenku8_Flutter` and no longer uses its update mirror. This prevents upstream releases from being presented as Riqing updates.

Android ARM64 release assets should be named:

`riqing-0.5.5-arm64-v8a.apk`

Release tags should include the build number, for example `v0.5.5+2286`.

> If this repository is still Private, anonymous in-app update checks cannot read its Releases. Make the repository and the intended Release public before relying on automatic updates.

## Installation

Android application ID:

`org.mewx.wenku8_flutter.online.fix`

It can coexist with the original app.

## Upstream, attribution and license

- Upstream project: `mikufoxxx/Wenku8`
- Original author: **MewX**
- This repository: `486Subaru/Wenku8_Flutter_Online`
- Source license: **GNU GPL v2**; see `LICENSE`.

Riqing is an unofficial derivative and is not affiliated with MewX, the Wenku8 website, or any third-party novel website unless explicitly stated by the relevant rights holder.

Builds published by this project's maintainer are provided without charge. GPL v2 rights and obligations are governed by the license text itself.

## Content and third-party services

This project does not operate a novel-content database. Online content is fetched from third-party services selected by the user. Novels, illustrations, covers, names, trademarks, and related materials remain the property of their respective rights holders. Users are responsible for complying with applicable law and each service's terms.

## Build checks

The Flutter CI performs Dart analysis, Flutter tests, an ARM64 Android release build, and Android native unit tests.
