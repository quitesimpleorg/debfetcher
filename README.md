# debfetcher
debfetcher enables fetching, installing and updating certain .deb packages from apt repos for non-Debian
distributions.

## Features
 - apt signature and package checksum verification
 - User-level installation

## Motivation
Many popular software packages are often distributed as .deb packages, targeting Ubuntu primarily.
Often they are not available in the repos of others distros. Even if they are, sometimes the version tends to be behind upstream for some time. They may also only be available as "unofficial" packages through user repositories such as AUR, PPA or Gentoo overlays.

Examples for such packages are: Brave, Signal-Desktop, Element-Desktop, Spotify etc.

debfetcher can fetch such packages from the official apt repos and keep them up to date.

The binaries in the .deb actually work on other distributions (often). In fact, distros
often use simply fetch the .deb packages from the apt repo in their templates. But they aren't always
quick to keep their template up to date with the latest upstream version.

There is thus hardly a practical benefit in using your distros package manager to install those. Your distro's
package is just a proxy  for the .deb. Although you can make a version bump yourself,
it is rather inconvenient and you'll have to monitor for new releases yourself. Although being out
of date is not a big problem often, it obviously can be when you are missing out on security updates.

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

But as said above, this is not my idea.  Using the .deb even for distros not based on Debian is an approach taken by distris for propritary packages or packages where building from source is a significant maintenance load (i. e. electron-based apps). Overall, the idea is tested and not new.


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
If you don't need/want a system-wide installation of a package, debfetcher can be used to install a package in your local user profile. Therefore, debfetcher can be used without polluting your /.

Refer to `debfetcher.user.conf.sample` to change the appropriate settings.

Execute
```
DEBFETCHER_CONFIG="/path/to/debfetcher.user.conf" ./debfetcher.sh get signal
```

Note: The config/data directories of the installed packages won't change, which may or may not be
problematic.

## Usage
### Install a package
```
debfetcher.sh get [packagename]
```

### Upgrade all
```
debfetcher.sh upgrade
```






