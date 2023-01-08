# debfetcher
debfetcher automates fetching  and installing certain .deb packages from apt repos.

## Features
 - apt signature and package checksum verification
 - User-level installation

## Motivation
Many popular software packages are often distributed as .deb packages, targeting Ubuntu primarily.
Often they are not available in the repos of others distros. Even if they are, sometimes the version tends to be behind upstream for some time. They may also only be available as "unofficial" packages through user repositories such as AUR, PPA or Gentoo overlays.

Examples for such packages are: Brave, Signal-Desktop, Element-Desktop, Spotify etc.

debfetcher can fetch such packages from the official apt repos.

The binaries in the .deb actually work on other distributions (often)

debfetcher simply identifies the latest version of a package in the corresponding apt repo, downloads it and then installs the binaries from the .deb.

debfetcher is intentionally dumb. It does not process post-install (or any other) scripts in the .deb, nor does it install any dependencies. It's not a package manager. What gets installed is controlled by the templates.

debfetcher verifies the repo signatures and .deb checksum (just like apt).


## Advantages
 - You get the official build and don't have to rely on third-parties
 - You don't have to wait for your distribution to make a version bump

## Status
It is, and will most certainly remain, a hack (although a useful one for me)

## FAQ

### Sounds overall rather dirty. Does this even work?
Naturally, this will not work for all packages due to ABI issues or library version mismatches.

However, using the .deb even for distros not based on debian  is an approach taken by distris for propritary packages or packages where building from source is a significant maintenance load (i. e. electron-based apps). Overall, the idea is tested and not new.

### What if not all dependencies are installed?
debfetcher aims to be distro-agnostic.  It will not install any dependencies.

If they are missing, you'll get an error (most likely when starting the app).
Hence, you will have to ensure yourself that they are installed. The packages debfetcher was tested on bundle some
of their dependencies. Also, in a typical Linux desktop installation chances are you already have all dependencies installed.


### Packages
Currently supported (= works for me) packages are in packages/.

### Templates
A template contains the repo URI, package name etc and specifies where to extract the binaries/libs contained in the .deb to. It may also install a .desktop file too.

## TODO
  - Sandboxed download / extraction
  - Rollback support

## Install
```
    mkdir /var/lib/debfetcher
    # It would not be unwise to verify those pubkeys
    cp -R pubkeys /var/lib/debfetcher
    # install defaults
    cp -R packages /var/lib/debfetcher
```

## User-level installation
If you don't need/want a system-wide installation , debfetcher can be used to install a package in your local user profile. Therefore, debfetcher can be used without polluting your /.

Refer to `debfetcher.user.conf.sample` to change the appropriate settings.

Execute
```
DEBFETCHER_CONFIG="/path/to/debfetcher.user.conf" ./debfetcher.sh get signal
```

## Usage
### Install a package
```
debfetcher.sh get [packagename]
```

### Upgrade all
```
debfetcher.sh upgrade
```






