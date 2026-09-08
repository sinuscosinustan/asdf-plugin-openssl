#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/openssl/openssl"
TOOL_NAME="openssl"

# Mirror used when the GitHub release asset is unreachable.
OPENSSL_SOURCE_MIRROR="https://www.openssl.org/source"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/openssl-[34]\..*' | cut -d/ -f3- |
		sed 's/^openssl-//'
}

list_all_versions() {
	list_github_tags | grep -Ev -- '-(alpha|beta|rc|pre)[0-9]*$'
}

release_url() {
	local version="$1"
	printf '%s/releases/download/openssl-%s/openssl-%s.tar.gz\n' "$GH_REPO" "$version" "$version"
}

mirror_url() {
	local version="$1"
	printf '%s/openssl-%s.tar.gz\n' "$OPENSSL_SOURCE_MIRROR" "$version"
}

# Verify a downloaded tarball against the `.sha256` published next to it.
verify_checksum() {
	local filename="$1" url="$2"
	local checksum_cmd expected actual

	if command -v sha256sum >/dev/null 2>&1; then
		checksum_cmd=(sha256sum)
	elif command -v shasum >/dev/null 2>&1; then
		checksum_cmd=(shasum -a 256)
	else
		echo "* No sha256sum or shasum available, skipping checksum verification." >&2
		return 0
	fi

	# The published file looks like: `<hex>  *openssl-<version>.tar.gz`
	if ! expected="$(curl "${curl_opts[@]}" "${url}.sha256" 2>/dev/null | awk '{print $1}')" ||
		[ -z "$expected" ]; then
		echo "* Could not fetch ${url}.sha256, skipping checksum verification." >&2
		return 0
	fi

	actual="$("${checksum_cmd[@]}" "$filename" | awk '{print $1}')"
	[ "$actual" = "$expected" ] ||
		fail "Checksum mismatch for $(basename "$filename"): expected $expected, got $actual"

	echo "* Checksum verified."
}

download_release() {
	local version filename url
	version="$1"
	filename="$2"

	url="$(release_url "$version")"

	echo "* Downloading $TOOL_NAME release $version..."
	if ! curl "${curl_opts[@]}" -o "$filename" "$url"; then
		url="$(mirror_url "$version")"
		echo "* Retrying from $url..."
		curl "${curl_opts[@]}" -o "$filename" "$url" || fail "Could not download $url"
	fi

	verify_checksum "$filename" "$url"
}

build_jobs() {
	if [ -n "${ASDF_CONCURRENCY:-}" ]; then
		printf '%s\n' "$ASDF_CONCURRENCY"
	elif command -v nproc >/dev/null 2>&1; then
		nproc
	elif command -v sysctl >/dev/null 2>&1; then
		sysctl -n hw.ncpu 2>/dev/null || echo 1
	else
		echo 1
	fi
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="$3"
	local build_dir

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	build_dir="$(mktemp -d)"
	# shellcheck disable=SC2064
	trap "rm -rf '$build_dir'" EXIT
	(
		cp -R "$ASDF_DOWNLOAD_PATH"/. "$build_dir"
		cd "$build_dir"

		local configure_opts
		read -r -a configure_opts <<<"${ASDF_OPENSSL_CONFIGURE_OPTIONS:-shared zlib}"

		echo "* Configuring $TOOL_NAME $version..."
		./Configure \
			--prefix="$install_path" \
			--openssldir="$install_path/ssl" \
			--libdir=lib \
			"${configure_opts[@]}" \
			"-Wl,-rpath,$install_path/lib" || fail "Could not configure $TOOL_NAME $version"

		echo "* Building $TOOL_NAME $version..."
		make -j"$(build_jobs)" || fail "Could not build $TOOL_NAME $version"

		# install_sw skips the man pages, which need pod2man.
		echo "* Installing $TOOL_NAME $version..."
		make install_sw install_ssldirs || fail "Could not install $TOOL_NAME $version"

		test -x "$install_path/bin/openssl" ||
			fail "Expected $install_path/bin/openssl to be executable."
		"$install_path/bin/openssl" version >/dev/null ||
			fail "Expected $install_path/bin/openssl to run."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}
