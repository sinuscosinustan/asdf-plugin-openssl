asdf-openssl
=============

## Dependencies

OpenSSL is built from source, so a working toolchain is required:

- `make`
- `perl` 5
- C99 compiler (`gcc` or `clang`)
- zlib development headers (`zlib1g-dev`, `zlib-devel`)

Plus `bash`, `curl`, `tar` and `git`.

## Install

Plugin:

```shell
asdf plugin add openssl https://github.com/sinuscosinustan/asdf-plugin-openssl.git
```

openssl:

```shell
# Show all installable versions
asdf list all openssl

# Install latest stable version
asdf install openssl latest

# Install a specific version
asdf install openssl 4.0.2

# Set a version globally (on your ~/.tool-versions file)
asdf set --home openssl latest

# Verify
openssl version
```

Both OpenSSL **3.x and 4.x** are supported.

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how
to install & manage versions.

## Build options

By default the plugin configures OpenSSL as:

```shell
./Configure --prefix=<install path> \
            --openssldir=<install path>/ssl \
            --libdir=lib \
            shared zlib \
            -Wl,-rpath,<install path>/lib
```

The trailing flag list can be replaced with `ASDF_OPENSSL_CONFIGURE_OPTIONS`:

```shell
ASDF_OPENSSL_CONFIGURE_OPTIONS="shared zlib no-tests enable-fips" asdf install openssl 4.0.2
```

Note that OpenSSL 4.0 removed engine support entirely, thus `no-engine` is not
required!

## Environment

The plugin ships an `exec-env` that exports the variables build systems look for:

`OPENSSL_DIR`, `OPENSSL_ROOT_DIR`, `OPENSSL_INCLUDE_DIR`, `OPENSSL_LIB_DIR`,
`SSL_CERT_DIR`, `PKG_CONFIG_PATH`, `CPPFLAGS`, `LDFLAGS`, and
`LD_LIBRARY_PATH` (`DYLD_LIBRARY_PATH` on macOS).

asdf applies these to the `openssl` shim itself, and to any command you run
through `asdf env openssl`:

```shell
# Inspect what gets exported
asdf env openssl

# Build something against this OpenSSL
asdf env openssl ./configure
asdf env openssl cargo build
```

That covers, among others, Rust's `openssl-sys`, CMake's `FindOpenSSL`, and
autotools/`pkg-config` based builds. To get the same variables into an
interactive shell, source them:

```shell
eval "$(asdf env openssl | sed 's/^/export /')"
```
