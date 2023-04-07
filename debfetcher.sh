#!/bin/sh
# (C) 2023 - Albert S. <dev-debfetcher@quitesimple.org>

# Simple, dumb .deb fetcher (and installer) for non-debian distros
set -e
set -u

# can be overwritten by config file
PUBKEY_PATH="/var/lib/debfetcher/pubkeys/"
TEMPLATES_PATH="/var/lib/debfetcher/packages/"
DB_PATH="/var/db/debfetcher/"
CACHE_DIR="/tmp/debfetcher"
KEEP_OLD=0
DEBFETCHER_INSTALL_DESTDIR="/"
DEBFETCHER_UNPRIV_USER="debfetcher"
DEBFETCHER_BIN_SYMLINK_DIR="/usr/bin"


DEBFETCHER_CONFIG="${DEBFETCHER_CONFIG:-"/etc/debfetcher/conf"}"

fail()
{
	echo $@ >&2
	exit 1
}


unpriv()
{
	if [ $(id -u) = "0" ] ; then
		first="$1"
		shift
		su ${DEBFETCHER_UNPRIV_USER} -s $(which "$first") -- $@
	else
		$@
	fi
}

ifroot()
{
	CMD="$1"
	shift
	if [ $(id -u) = "0" ] ; then
		$CMD $@
	fi
}

check_debfetcher_dependencies()
{
	curl --version &>/dev/null || fail "curl is missing or broken"
	echo -e "1\n2" | sort -V &>/dev/null || fail "sort -V not available it seems"
	gpg --version &>/dev/null || fail "gpg is missing or broken"
	ar --version &>/dev/null || fail "ar is missing or broken"
	tar --version &>/dev/null || fail "tar is missing or broken"
	patchelf --version &>/dev/null || fail "patchelf is missing or broken"

}

get_higher_version()
{
	echo -e "$1\n$2" | sort -V | tail -n 1
}


read_config()
{
	if [ -f "${DEBFETCHER_CONFIG}" ] ; then
		source "${DEBFETCHER_CONFIG}"
	fi
}

print_usage()
{
	echo "$0 get [package] - install/update the specified package"
	echo "$0 upgrade - check each package for updates and install them"
}


verify_sig()
{
	set +e
	gpg --no-default-keyring --keyring "$1" --quiet --verify 2> "${CACHE_DIR}/last_gnupg_verify_result"
	if [ $? -ne 0 ] ; then
		fail "Signature check failed - See "${CACHE_DIR}/last_gnupg_verify_result""
	fi
	set -e
}



debfetcher_install()
{
	TEMPLATE_NAME=$(basename "$1")
	template="${TEMPLATES_PATH}/${TEMPLATE_NAME}.debfetcher"

	source $template

	DEB_PATH="$2"
	VERSION="$3"

	echo "${TEMPLATE_NAME}: Installing: version ${VERSION}, file: ${DEB_PATH}"

	TEMPDIR=$( mktemp -d -p "${CACHE_DIR}" )
	ifroot chown "${DEBFETCHER_UNPRIV_USER}" "$TEMPDIR"
	cd "$TEMPDIR"
	mv "$DEB_PATH" .

	unpriv ar x "$( basename "$DEB_PATH")"

	mkdir data_contents
	ifroot chown "${DEBFETCHER_UNPRIV_USER}" data_contents

	datapkg="data.tar.xz"
	[ -f "$datapkg" ] || datapkg="data.tar.gz"
	[ -f "$datapkg" ] || datapkg="data.tar.bz2"
	[ -f "$datapkg" ] || fail "no data archive found in .deb"

	tar xf "$datapkg" -C data_contents
	cd data_contents

	#TODO: split doesn't have a benefit yet
	pre_install || fail "Pre-install failed"
	install || fail "Install failed"
	post_install || fail "Post-install failed"

	echo "$VERSION" > "/${DB_PATH}/${TEMPLATE_NAME}/version"
}



debfetcher_get()
{
	TEMPLATE_NAME=$(basename "$1")
	template="${TEMPLATES_PATH}/${TEMPLATE_NAME}.debfetcher"
	[ -f "$template" ] || fail "Unknown package $1"

	source $template


	echo "${TEMPLATE_NAME}: Checking for new version..."
	INRELEASE_URL="${APTURL}/dists/${DISTRO}/InRelease"
	INRELEASE_CONTENT="$(unpriv curl -Ls $INRELEASE_URL)"

	echo "${TEMPLATE_NAME}: Verifying apt repository PGP signature..."
	echo "${INRELEASE_CONTENT}" | verify_sig "${PUBKEY}"

	# Fetch
	PACKAGES_SHA256SUM_SHOULD=$(echo "${INRELEASE_CONTENT}" | grep -E "${REPO}/binary-amd64/Packages$"  | awk '{print $1}' | grep -E "^[0-9a-z]{64}$")

	PACKAGES_URL="${APTURL}/dists/${DISTRO}/${REPO}/binary-amd64/Packages"

	PACKAGES_CONTENT="$(unpriv curl -Ls "$PACKAGES_URL" && echo .)"
	PACKAGES_CONTENT="${PACKAGES_CONTENT%.}"

	PACKAGES_SHA256SUM_IS=$( echo -n "$PACKAGES_CONTENT" | sha256sum | awk '{print $1}' )

	if [ "${PACKAGES_SHA256SUM_SHOULD}" != "${PACKAGES_SHA256SUM_IS}" ] ; then
		fail "${TEMPLATE_NAME}: Packages checksum do not match for $1: ${PACKAGES_SHA256SUM_SHOULD} and ${PACKAGES_SHA256SUM_IS} "
	fi

	NORMALIZED=$(echo "${PACKAGES_CONTENT}" | grep -E "(Package:|Filename:|SHA256:|Version:)" | tr  '\n' ' ' | sed -e 's/Package:/\nPackage:/g')

	LATEST_VERSION=$( echo "${NORMALIZED}" | grep "Package: ${PACKAGE} " | sed -e 's/.*Version: //g' | awk '{print $1}' | sort -V | tail -n 1 )

	CURRENT_VERSION="$( cat "${DB_PATH}/${TEMPLATE_NAME}/version" 2>/dev/null || true )"

	if [ -z "${CURRENT_VERSION}" ] ; then
		echo "${TEMPLATE_NAME}: First install of "$TEMPLATE_NAME", version $LATEST_VERSION"
	else
		if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ] ; then
			HIGHER=$(get_higher_version "$CURRENT_VERSION" "$LATEST_VERSION")


			if [ "$HIGHER" != "$LATEST_VERSION" ] ; then
				fail "Local version is newer than repo version"
			fi

			echo "${TEMPLATE_NAME}: Will upgrade "$TEMPLATE_NAME" from "$CURRENT_VERSION" to $LATEST_VERSION"
		else
			echo "${TEMPLATE_NAME}: Already up to date"
			return
		fi
	fi

	FILENAME=$( echo "${NORMALIZED}" | grep "Package: ${PACKAGE} " | grep "Version: $LATEST_VERSION" | sed -e 's/.*Filename: //g' | awk '{print $1}' )
	FILENAME_BASENAME=$(basename "${FILENAME}")

	DEB_URL="${APTURL}/${FILENAME}"

	DEB_TARGET_PATH="${CACHE_DIR}/${FILENAME_BASENAME}"

	touch "${DEB_TARGET_PATH}"
	ifroot chown "${DEBFETCHER_UNPRIV_USER}" "${DEB_TARGET_PATH}"

	echo "${TEMPLATE_NAME}: Fetching .deb..."
	unpriv curl -Ls -o - "${DEB_URL}" > "${DEB_TARGET_PATH}" || fail "Fetch failure"

	echo "${TEMPLATE_NAME}: Verifying checksums..."
	DEB_HASH_MUST=$(echo "${NORMALIZED}" | grep "Package: ${PACKAGE} " | grep "Version: $LATEST_VERSION" | sed -e 's/.*SHA256: //g' | awk '{print $1}' )

	DEB_HASH_IS=$(sha256sum "${DEB_TARGET_PATH}" | awk '{print $1}' )

	if [ "${DEB_HASH_IS}" != "${DEB_HASH_MUST}" ] ; then
		fail "${TEMPLATE_NAME}: .deb checksum mismatch for $TEMPLATE_NAME, file ${DEB_TARGET_PATH}: ${DEB_HASH_IS}, ${DEB_HASH_MUST}"
	fi

	debfetcher_install "${TEMPLATE_NAME}" "${DEB_TARGET_PATH}" "${LATEST_VERSION}"
}

init_db()
{
	for template in ${TEMPLATES_PATH}/* ; do
		basename=$(basename "$template" | sed -e 's/.debfetcher//g')
		mkdir -p "${DB_PATH}/${basename}"
	done

}

init_cache()
{
	mkdir -p "${CACHE_DIR}"
	ifroot chown root:root "${CACHE_DIR}"
	ifroot chmod o=--- "${CACHE_DIR}"
	rm -rf -- ${CACHE_DIR}/*
}


check_debfetcher_dependencies
read_config

init_db
init_cache


[ -w "${DEBFETCHER_INSTALL_DESTDIR}" ] || fail "No write access in install destdir"

mkdir -p "${DB_PATH}"

if [ $# -lt 1 ] ; then
	print_usage
	exit 1
fi

CMD="$1"
if [ "$CMD" = "get" ] ; then
	if [ $# -lt 2 ] ; then
		echo "$0 get [package]"
		exit 1
	fi
	PACKAGE="$2"
	debfetcher_get "${PACKAGE}"
fi

if [ "$CMD" = "upgrade" ] ; then
	for template in ${TEMPLATES_PATH}/* ; do
		template=$(basename "${template}" | sed -e 's/.debfetcher//g' )
		if [ -f "${DB_PATH}/${template}/version" ]  ; then
			debfetcher_get ${template}
		fi
	done
fi

exit 0




