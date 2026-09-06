TERMUX_PKG_HOMEPAGE=https://www.mesa3d.org
TERMUX_PKG_DESCRIPTION="Mesa Freedreno Gallium driver for native Termux KGSL on Android 10"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_LICENSE_FILE="docs/license.rst"
TERMUX_PKG_MAINTAINER="@ayumi36"
TERMUX_PKG_VERSION="26.2.0"
TERMUX_PKG_REVISION=2
TERMUX_PKG_API_LEVEL=29
TERMUX_PKG_BLACKLISTED_ARCHES="arm, i686, x86_64"
TERMUX_PKG_SRCURL=git+https://github.com/ayumi36/mesa-for-android-container.git
TERMUX_PKG_GIT_BRANCH=termux-fd512-legacy-ion
_COMMIT=87e441410517948be65a77f51e4d57e4a4db7f80
TERMUX_PKG_AUTO_UPDATE=false
TERMUX_PKG_DEPENDS="libandroid-shmem, libc++, libdrm, libglvnd, libwayland, libx11, libxext, libxfixes, libxshmfence, libxxf86vm, ncurses, zlib, zstd"
TERMUX_PKG_SUGGESTS="mesa-dev"
TERMUX_PKG_BUILD_DEPENDS="libwayland-protocols, libxrandr, xorgproto"
TERMUX_PKG_BREAKS="osmesa, osmesa-demos"
TERMUX_PKG_CONFLICTS="libmesa, ndk-sysroot (<= 25b), osmesa"
TERMUX_PKG_REPLACES="libmesa, osmesa"

# This is lfdevs/termux-packages@8f165a1's proven native Termux:X11
# Freedreno/KGSL recipe, narrowed to Gallium Freedreno for Adreno 512.
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
--cmake-prefix-path $TERMUX_PREFIX
-Dandroid-libbacktrace=disabled
-Dbuild-tests=false
-Ddatasources=
-Degl=enabled
-Degl-native-platform=x11
-Dfreedreno-kmds=kgsl
-Dgallium-drivers=freedreno
-Dgallium-mediafoundation=disabled
-Dgallium-rusticl=false
-Dgallium-va=disabled
-Dgbm=enabled
-Dgles1=disabled
-Dgles2=enabled
-Dglvnd=enabled
-Dglx=dri
-Dintel-rt=disabled
-Dlibunwind=disabled
-Dllvm=disabled
-Dlmsensors=disabled
-Dmicrosoft-clc=disabled
-Dopengl=true
-Dplatforms=x11,wayland
-Dshared-llvm=disabled
-Dvalgrind=disabled
-Dvulkan-drivers=
-Dvulkan-layers=
-Dxmlconfig=disabled
"

termux_step_post_get_source() {
	if git -C "$TERMUX_PKG_SRCDIR" rev-parse --is-shallow-repository | grep -q true; then
		git -C "$TERMUX_PKG_SRCDIR" fetch --unshallow
	fi
	git -C "$TERMUX_PKG_SRCDIR" checkout "$_COMMIT"

	# Use Termux-provided dependencies, never Meson wrap downloads.
	rm -rf subprojects
}

termux_step_pre_configure() {
	termux_setup_cmake

	CPPFLAGS+=" -D__USE_GNU"
	LDFLAGS+=" -landroid-shmem"

	_WRAPPER_BIN=$TERMUX_PKG_BUILDDIR/_wrapper/bin
	mkdir -p "$_WRAPPER_BIN"
	if [ "$TERMUX_ON_DEVICE_BUILD" = "false" ]; then
		sed 's|@CMAKE@|'"$(command -v cmake)"'|g' 			"$TERMUX_PKG_BUILDER_DIR/cmake-wrapper.in" 			> "$_WRAPPER_BIN/cmake"
		chmod 0700 "$_WRAPPER_BIN/cmake"
		termux_setup_wayland_cross_pkg_config_wrapper
	fi
	export PATH="${_WRAPPER_BIN}:${PATH}"
}

termux_step_post_configure() {
	rm -f "$_WRAPPER_BIN/cmake"
}

termux_step_post_make_install() {
	# Avoid hard links in the package payload.
	local f1
	for f1 in "$TERMUX_PREFIX"/lib/dri/*; do
		[ -f "$f1" ] || continue
		local f2
		for f2 in "$TERMUX_PREFIX"/lib/dri/*; do
			if [ -f "$f2" ] && [ "$f1" != "$f2" ] && 				[ "$(stat -c '%i' "$f1")" = "$(stat -c '%i' "$f2")" ]; then
				ln -sfr "$f1" "$f2"
			fi
		done
	done

	ln -sf libEGL_mesa.so "$TERMUX_PREFIX/lib/libEGL_mesa.so.0"
	ln -sf libGLX_mesa.so "$TERMUX_PREFIX/lib/libGLX_mesa.so.0"
}
