dnl This Source Code Form is subject to the terms of the Mozilla Public
dnl License, v. 2.0. If a copy of the MPL was not distributed with this
dnl file, You can obtain one at http://mozilla.org/MPL/2.0/.

dnl Modernized for unified-LLVM NDKs (r19+): there are no standalone GCC
dnl toolchains, no platforms/android-N/arch-* include dirs, and no
dnl sources/cxx-stl -- clang's driver + the unified sysroot handle all of it,
dnl and libc++ comes from the toolchain itself.

AC_DEFUN([MOZ_ANDROID_NDK],
[

MOZ_ARG_WITH_STRING(android-cxx-stl,
[  --with-android-cxx-stl=VALUE
                          use the specified C++ STL (libstdc++, libc++)],
    android_cxx_stl=$withval,
    android_cxx_stl=libc++)

case "$target" in
*-android*|*-linuxandroid*)
    dnl $android_platform is set for us by Python configure (unified sysroot
    dnl on r19+). The triplet-prefixed clang already knows its sysroot; these
    dnl flags keep bionic ABI flags and -llog parity with the historical port.
    CFLAGS="-fno-short-enums -fno-exceptions $CFLAGS"
    CXXFLAGS="-fno-short-enums -fno-exceptions $CXXFLAGS"
    ASFLAGS="-DANDROID $ASFLAGS"

    LIBS="-llog $LIBS"
    ANDROID_PLATFORM="${android_platform}"

    AC_DEFINE(ANDROID)
    AC_SUBST(ANDROID_PLATFORM)

    ;;
esac

])

AC_DEFUN([MOZ_ANDROID_CPU_ARCH],
[

if test "$OS_TARGET" = "Android"; then
    case "${CPU_ARCH}-${MOZ_ARCH}" in
    arm-armv7*)
        ANDROID_CPU_ARCH=armeabi-v7a
        ;;
    arm-*)
        ANDROID_CPU_ARCH=armeabi
        ;;
    x86-*)
        ANDROID_CPU_ARCH=x86
        ;;
    mips32-*) # When target_cpu is mipsel, CPU_ARCH is mips32
        ANDROID_CPU_ARCH=mips
        ;;
    aarch64-*)
        ANDROID_CPU_ARCH=arm64-v8a
        ;;
    esac

    AC_SUBST(ANDROID_CPU_ARCH)
fi
])

AC_DEFUN([MOZ_ANDROID_STLPORT],
[

if test "$OS_TARGET" = "Android"; then
    dnl Unified NDKs ship libc++ inside the toolchain sysroot
    dnl (sysroot/usr/lib/<triple>/); the clang++ driver links it
    dnl automatically. Nothing to locate here.
    MOZ_ANDROID_CXX_STL=$android_cxx_stl
fi
AC_SUBST([MOZ_ANDROID_CXX_STL])
AC_SUBST([STLPORT_LIBS])

])


AC_DEFUN([concat],[$1$2$3$4])

dnl Find a component of an AAR.
dnl Arg 1: variable name to expose, like ANDROID_SUPPORT_V4_LIB.
dnl Arg 2: path to component.
dnl Arg 3: if non-empty, expect and require component.
AC_DEFUN([MOZ_ANDROID_AAR_COMPONENT], [
  ifelse([$3], ,
  [
    if test -e "$$1" ; then
      AC_MSG_ERROR([Found unexpected exploded $1!])
    fi
  ],
  [
    AC_MSG_CHECKING([for $1])
    $1="$2"
    if ! test -e "$$1" ; then
      AC_MSG_ERROR([Could not find required exploded $1!])
    fi
    AC_MSG_RESULT([$$1])
    AC_SUBST($1)
  ])
])

dnl Find an AAR and expose variables representing its exploded components.
dnl AC_SUBSTs ANDROID_NAME_{AAR,AAR_RES,AAR_LIB,AAR_INTERNAL_LIB}.
dnl Arg 1: name, like play-services-base
dnl Arg 2: version, like 7.8.0
dnl Arg 3: extras subdirectory, either android or google
dnl Arg 4: package subdirectory, like com/google/android/gms
dnl Arg 5: if non-empty, expect and require internal_impl JAR.
dnl Arg 6: if non-empty, expect and require assets/ directory.
AC_DEFUN([MOZ_ANDROID_AAR],[
  define([local_aar_var_base], translit($1, [-a-z], [_A-Z]))
  define([local_aar_var], concat(ANDROID_, local_aar_var_base, _AAR))
  local_aar_var="$ANDROID_SDK_ROOT/extras/$3/m2repository/$4/$1/$2/$1-$2.aar"
  AC_MSG_CHECKING([for $1 AAR])
  if ! test -e "$local_aar_var" ; then
    AC_MSG_ERROR([You must download the $1 AAR.  Run the Android SDK tool and install the Android and Google Support Repositories under Extras.  See https://developer.android.com/tools/extras/support-library.html for more info. (Looked for $local_aar_var)])
  fi
  AC_SUBST(local_aar_var)
  AC_MSG_RESULT([$local_aar_var])

  if ! $PYTHON -m mozbuild.action.explode_aar --destdir=$MOZ_BUILD_ROOT/dist/exploded-aar $local_aar_var ; then
    AC_MSG_ERROR([Could not explode $local_aar_var!])
  fi

  define([root], $MOZ_BUILD_ROOT/dist/exploded-aar/$1-$2/)
  MOZ_ANDROID_AAR_COMPONENT(concat(local_aar_var, _LIB), concat(root, $1-$2-classes.jar), REQUIRED)
  MOZ_ANDROID_AAR_COMPONENT(concat(local_aar_var, _RES), concat(root, res), REQUIRED)
  MOZ_ANDROID_AAR_COMPONENT(concat(local_aar_var, _INTERNAL_LIB), concat(root, libs/$1-$2-internal_impl-$2.jar), $5)
  MOZ_ANDROID_AAR_COMPONENT(concat(local_aar_var, _ASSETS), concat(root, assets), $6)
])

AC_DEFUN([MOZ_ANDROID_GOOGLE_PLAY_SERVICES],
[

if test -n "$MOZ_NATIVE_DEVICES" ; then
    AC_SUBST(MOZ_NATIVE_DEVICES)

    MOZ_ANDROID_AAR(play-services-base, $ANDROID_GOOGLE_PLAY_SERVICES_VERSION, google, com/google/android/gms)
    MOZ_ANDROID_AAR(play-services-basement, $ANDROID_GOOGLE_PLAY_SERVICES_VERSION, google, com/google/android/gms)
    MOZ_ANDROID_AAR(play-services-cast, $ANDROID_GOOGLE_PLAY_SERVICES_VERSION, google, com/google/android/gms)
    MOZ_ANDROID_AAR(mediarouter-v7, $ANDROID_SUPPORT_LIBRARY_VERSION, android, com/android/support, REQUIRED_INTERNAL_IMPL)
fi

])

AC_DEFUN([MOZ_ANDROID_GOOGLE_CLOUD_MESSAGING],
[

if test -n "$MOZ_ANDROID_GCM" ; then
    MOZ_ANDROID_AAR(play-services-base, $ANDROID_GOOGLE_PLAY_SERVICES_VERSION, google, com/google/android/gms)
    MOZ_ANDROID_AAR(play-services-basement, $ANDROID_GOOGLE_PLAY_SERVICES_VERSION, google, com/google/android/gms)
    MOZ_ANDROID_AAR(play-services-gcm, $ANDROID_GOOGLE_PLAY_SERVICES_VERSION, google, com/google/android/gms)
    MOZ_ANDROID_AAR(play-services-measurement, $ANDROID_GOOGLE_PLAY_SERVICES_VERSION, google, com/google/android/gms)
fi

])

AC_DEFUN([MOZ_ANDROID_INSTALL_TRACKING],
[

if test -n "$MOZ_INSTALL_TRACKING"; then
    AC_SUBST(MOZ_INSTALL_TRACKING)
    MOZ_ANDROID_AAR(play-services-ads, $ANDROID_GOOGLE_PLAY_SERVICES_VERSION, google, com/google/android/gms)
    MOZ_ANDROID_AAR(play-services-basement, $ANDROID_GOOGLE_PLAY_SERVICES_VERSION, google, com/google/android/gms)
fi

])

dnl Configure an Android SDK.
dnl Arg 1: target SDK version, like 34.
dnl Arg 2: list of build-tools versions, like "34.0.0".
dnl Arg 3 (optional): if non-empty, require legacy support-library AARs.
AC_DEFUN([MOZ_ANDROID_SDK],
[

MOZ_ARG_WITH_STRING(android-sdk,
[  --with-android-sdk=DIR
                          location where the Android SDK can be found],
    android_sdk_root=$withval,
    android_sdk_root="$ANDROID_HOME")

android_sdk_root=${android_sdk_root%/platforms/android-*}

case "$target" in
*-android*|*-linuxandroid*)
    if test -z "$android_sdk_root" ; then
        AC_MSG_ERROR([You must specify --with-android-sdk=/path/to/sdk (or set ANDROID_HOME) when targeting Android.])
    fi

    dnl Prefer the requested target SDK, else take the newest installed
    dnl platforms/android-* dir.
    android_target_sdk=$1
    if test ! -e "$android_sdk_root/platforms/android-$android_target_sdk/source.properties" ; then
        _newest=`ls -d "$android_sdk_root"/platforms/android-* 2>/dev/null | sed 's/.*android-//' | sort -n | tail -1`
        if test -n "$_newest" ; then
            android_target_sdk=$_newest
        else
            AC_MSG_ERROR([No Android SDK platform found under $android_sdk_root/platforms])
        fi
    fi
    android_sdk=$android_sdk_root/platforms/android-$android_target_sdk
    AC_MSG_CHECKING([for Android SDK platform])
    AC_MSG_RESULT([$android_sdk])

    AC_MSG_CHECKING([for Android build-tools])
    android_build_tools_base="$android_sdk_root"/build-tools
    android_build_tools_version=""
    _bt_versions="$2"
    if test -z "$_bt_versions" ; then
        _bt_versions=`ls "$android_build_tools_base" 2>/dev/null | sort -rn`
    fi
    for version in $_bt_versions; do
        android_build_tools="$android_build_tools_base"/$version
        if test -d "$android_build_tools" -a -f "$android_build_tools/aapt"; then
            android_build_tools_version=$version
            AC_MSG_RESULT([$android_build_tools])
            break
        fi
    done
    if test "$android_build_tools_version" = ""; then
        AC_MSG_ERROR([No usable Android build-tools found under "$android_build_tools_base"])
    fi

    MOZ_PATH_PROG(ZIPALIGN, zipalign, :, [$android_build_tools])
    MOZ_PATH_PROG(DX, dx, :, [$android_build_tools])
    MOZ_PATH_PROG(D8, d8, :, [$android_build_tools])
    MOZ_PATH_PROG(AAPT, aapt, :, [$android_build_tools])
    MOZ_PATH_PROG(AAPT2, aapt2, :, [$android_build_tools])
    MOZ_PATH_PROG(AIDL, aidl, :, [$android_build_tools])
    MOZ_PATH_PROG(APKSIGNER, apksigner, :, [$android_build_tools])
    if test -z "$ZIPALIGN" -o "$ZIPALIGN" = ":"; then
      AC_MSG_ERROR([The program zipalign was not found in $android_build_tools.])
    fi
    if test \( -z "$DX" -o "$DX" = ":" \) -a \( -z "$D8" -o "$D8" = ":" \); then
      AC_MSG_ERROR([No dexer found (dx or d8) in $android_build_tools.])
    fi
    if test -z "$AAPT" -o "$AAPT" = ":"; then
      AC_MSG_ERROR([The program aapt was not found in $android_build_tools.])
    fi
    if test -z "$AIDL" -o "$AIDL" = ":"; then
      AC_MSG_ERROR([The program aidl was not found in $android_build_tools.])
    fi

    android_platform_tools="$android_sdk_root"/platform-tools
    AC_MSG_CHECKING([for Android platform-tools])
    if test -d "$android_platform_tools" -a -f "$android_platform_tools/adb"; then
        AC_MSG_RESULT([$android_platform_tools])
    else
        AC_MSG_ERROR([You must install the Android platform-tools.])
    fi

    MOZ_PATH_PROG(ADB, adb, :, [$android_platform_tools])
    if test -z "$ADB" -o "$ADB" = ":"; then
      AC_MSG_ERROR([The program adb was not found.])
    fi

    dnl cmdline-tools carries the lint jars the annotation processor
    dnl needs; fall back to the legacy tools/ dir, then emulator/.
    android_tools=""
    for _d in "$android_sdk_root"/cmdline-tools/latest "$android_sdk_root"/tools "$android_sdk_root"/emulator; do
        if test -d "$_d"; then
            android_tools="$_d"
            break
        fi
    done
    MOZ_PATH_PROG(EMULATOR, emulator, :, ["$android_sdk_root"/emulator:"$android_sdk_root"/tools])

    ANDROID_TARGET_SDK="${android_target_sdk}"
    ANDROID_SDK="${android_sdk}"
    ANDROID_SDK_ROOT="${android_sdk_root}"
    ANDROID_TOOLS="${android_tools}"
    ANDROID_BUILD_TOOLS_VERSION="$android_build_tools_version"
    AC_DEFINE_UNQUOTED(ANDROID_TARGET_SDK,$ANDROID_TARGET_SDK)
    AC_SUBST(ANDROID_TARGET_SDK)
    AC_SUBST(ANDROID_SDK_ROOT)
    AC_SUBST(ANDROID_SDK)
    AC_SUBST(ANDROID_TOOLS)
    AC_SUBST(ANDROID_BUILD_TOOLS_VERSION)

    dnl The frontend builds against androidx artifacts fetched by
    dnl scripts/fetch-androidx.sh into a maven-layout repo at
    dnl $SDK/extras/androidx/m2repository.  Arg 3 non-empty requires them.
    ifelse([$3], , , [
    ANDROIDX_REPO="$ANDROID_SDK_ROOT/extras/androidx/m2repository"
    AC_MSG_CHECKING([for androidx repository])
    if ! test -d "$ANDROIDX_REPO" ; then
        AC_MSG_ERROR([androidx repository not found at $ANDROIDX_REPO. Run scripts/fetch-androidx.sh with ANDROID_HOME set.])
    fi
    AC_MSG_RESULT([$ANDROIDX_REPO])

    ANDROIDX_EXTRA_JARS=
    ANDROIDX_EXTRA_RES_DIRS=
    ANDROIDX_EXTRA_PACKAGES=
    for ax_spec in \
        androidx.annotation:annotation:1.1.0:jar \
        androidx.collection:collection:1.1.0:jar \
        androidx.core:core:1.2.0:aar \
        androidx.arch.core:core-common:2.1.0:jar \
        androidx.arch.core:core-runtime:2.1.0:aar \
        androidx.lifecycle:lifecycle-common:2.1.0:jar \
        androidx.lifecycle:lifecycle-runtime:2.1.0:aar \
        androidx.lifecycle:lifecycle-livedata-core:2.1.0:aar \
        androidx.lifecycle:lifecycle-viewmodel:2.1.0:aar \
        androidx.versionedparcelable:versionedparcelable:1.1.0:aar \
        androidx.activity:activity:1.0.0:aar \
        androidx.fragment:fragment:1.1.0:aar \
        androidx.savedstate:savedstate:1.0.0:aar \
        androidx.loader:loader:1.0.0:aar \
        androidx.customview:customview:1.1.0:aar \
        androidx.viewpager:viewpager:1.0.0:aar \
        androidx.viewpager2:viewpager2:1.0.0:aar \
        androidx.drawerlayout:drawerlayout:1.1.0:aar \
        androidx.swiperefreshlayout:swiperefreshlayout:1.0.0:aar \
        androidx.cursoradapter:cursoradapter:1.0.0:aar \
        androidx.interpolator:interpolator:1.0.0:aar \
        androidx.coordinatorlayout:coordinatorlayout:1.1.0:aar \
        androidx.localbroadcastmanager:localbroadcastmanager:1.0.0:aar \
        androidx.legacy:legacy-support-core-utils:1.0.0:aar \
        androidx.appcompat:appcompat:1.1.0:aar \
        androidx.appcompat:appcompat-resources:1.1.0:aar \
        androidx.vectordrawable:vectordrawable:1.1.0:aar \
        androidx.vectordrawable:vectordrawable-animated:1.1.0:aar \
        androidx.recyclerview:recyclerview:1.1.0:aar \
        androidx.cardview:cardview:1.0.0:aar \
        androidx.transition:transition:1.2.0:aar \
        androidx.browser:browser:1.0.0:aar \
        androidx.palette:palette:1.0.0:aar \
        androidx.mediarouter:mediarouter:1.0.0:aar \
        androidx.media:media:1.1.0:aar \
        com.google.android.material:material:1.1.0:aar \
    ; do
        ax_group=${ax_spec%%:*}; ax_rest=${ax_spec#*:}
        ax_name=${ax_rest%%:*}; ax_rest=${ax_rest#*:}
        ax_version=${ax_rest%%:*}; ax_type=${ax_rest##*:}
        ax_path=`echo "$ax_group" | tr . /`/$ax_name/$ax_version/$ax_name-$ax_version.$ax_type
        ax_file="$ANDROIDX_REPO/$ax_path"
        AC_MSG_CHECKING([for $ax_name $ax_version])
        if ! test -e "$ax_file" ; then
            AC_MSG_ERROR([missing androidx artifact $ax_file. Run scripts/fetch-androidx.sh with ANDROID_HOME set.])
        fi
        AC_MSG_RESULT([$ax_file])
        if test "$ax_type" = "jar" ; then
            ANDROIDX_EXTRA_JARS="$ANDROIDX_EXTRA_JARS $ax_file"
        else
            if ! $PYTHON -m mozbuild.action.explode_aar --destdir="$MOZ_BUILD_ROOT/dist/exploded-aar" "$ax_file" ; then
                AC_MSG_ERROR([could not explode $ax_file])
            fi
            ax_root="$MOZ_BUILD_ROOT/dist/exploded-aar/$ax_name-$ax_version"
            ANDROIDX_EXTRA_JARS="$ANDROIDX_EXTRA_JARS $ax_root/$ax_name-$ax_version-classes.jar"
            if test -d "$ax_root/res" ; then
                ANDROIDX_EXTRA_RES_DIRS="$ANDROIDX_EXTRA_RES_DIRS $ax_root/res"
                ax_pkg=`grep -m1 'package="' "$ax_root/AndroidManifest.xml" | cut -d'"' -f2`
                ANDROIDX_EXTRA_PACKAGES="$ANDROIDX_EXTRA_PACKAGES $ax_pkg"
            fi
        fi
    done
    ])
    AC_SUBST(ANDROIDX_EXTRA_JARS)
    AC_SUBST(ANDROIDX_EXTRA_RES_DIRS)
    AC_SUBST(ANDROIDX_EXTRA_PACKAGES)
    ;;
esac

MOZ_ARG_WITH_STRING(android-min-sdk,
[  --with-android-min-sdk=[VER]     Impose a minimum SDK version],
[ MOZ_ANDROID_MIN_SDK_VERSION=$withval ])

MOZ_ARG_WITH_STRING(android-max-sdk,
[  --with-android-max-sdk=[VER]     Impose a maximum SDK version],
[ MOZ_ANDROID_MAX_SDK_VERSION=$withval ])

if test -n "$MOZ_ANDROID_MIN_SDK_VERSION"; then
    if test -n "$MOZ_ANDROID_MAX_SDK_VERSION"; then
        if test $MOZ_ANDROID_MAX_SDK_VERSION -lt $MOZ_ANDROID_MIN_SDK_VERSION ; then
            AC_MSG_ERROR([--with-android-max-sdk must be at least the value of --with-android-min-sdk.])
        fi
    fi

    if test $MOZ_ANDROID_MIN_SDK_VERSION -gt $ANDROID_TARGET_SDK ; then
        AC_MSG_ERROR([--with-android-min-sdk is expected to be less than $ANDROID_TARGET_SDK])
    fi

    AC_DEFINE_UNQUOTED(MOZ_ANDROID_MIN_SDK_VERSION, $MOZ_ANDROID_MIN_SDK_VERSION)
    AC_SUBST(MOZ_ANDROID_MIN_SDK_VERSION)
fi

if test -n "$MOZ_ANDROID_MAX_SDK_VERSION"; then
    AC_DEFINE_UNQUOTED(MOZ_ANDROID_MAX_SDK_VERSION, $MOZ_ANDROID_MAX_SDK_VERSION)
    AC_SUBST(MOZ_ANDROID_MAX_SDK_VERSION)
fi

])
