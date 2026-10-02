#!/bin/bash
# Fetch the androidx artifacts needed by the mobile/android frontend into a
# maven-layout repository at $ANDROID_HOME/extras/androidx/m2repository.
#
# The make-based build resolves AARs/JARs from this repository at configure
# time (see MOZ_ANDROIDX_LIBS in build/autoconf/android.m4), exploding AARs
# into $objdir/dist/exploded-aar like the legacy support-library flow.
#
# Artifact selection: the last pre-Kotlin train of androidx releases
# (core 1.1.0 era, material 1.1.0), covering every androidx class referenced
# by the vendored sources plus their compile-time transitive dependencies.
set -euo pipefail

REPO="${ANDROID_HOME:?set ANDROID_HOME}/extras/androidx/m2repository"
BASE="https://dl.google.com/dl/android/maven2"
CENTRAL="https://repo1.maven.org/maven2"

# group:name:version:type[:repo]  (type = aar|jar, repo = google|central)
ARTIFACTS="
androidx.annotation:annotation:1.1.0:jar
androidx.collection:collection:1.1.0:jar
androidx.core:core:1.2.0:aar
androidx.arch.core:core-common:2.1.0:jar
androidx.arch.core:core-runtime:2.1.0:aar
androidx.lifecycle:lifecycle-common:2.1.0:jar
androidx.lifecycle:lifecycle-runtime:2.1.0:aar
androidx.lifecycle:lifecycle-livedata-core:2.1.0:aar
androidx.lifecycle:lifecycle-viewmodel:2.1.0:aar
androidx.versionedparcelable:versionedparcelable:1.1.0:aar
androidx.activity:activity:1.0.0:aar
androidx.fragment:fragment:1.1.0:aar
androidx.savedstate:savedstate:1.0.0:aar
androidx.loader:loader:1.0.0:aar
androidx.customview:customview:1.1.0:aar
androidx.viewpager:viewpager:1.0.0:aar
androidx.viewpager2:viewpager2:1.0.0:aar
androidx.drawerlayout:drawerlayout:1.1.0:aar
androidx.swiperefreshlayout:swiperefreshlayout:1.0.0:aar
androidx.cursoradapter:cursoradapter:1.0.0:aar
androidx.interpolator:interpolator:1.0.0:aar
androidx.coordinatorlayout:coordinatorlayout:1.1.0:aar
androidx.localbroadcastmanager:localbroadcastmanager:1.0.0:aar
androidx.legacy:legacy-support-core-utils:1.0.0:aar
androidx.appcompat:appcompat:1.1.0:aar
androidx.appcompat:appcompat-resources:1.1.0:aar
androidx.vectordrawable:vectordrawable:1.1.0:aar
androidx.vectordrawable:vectordrawable-animated:1.1.0:aar
androidx.recyclerview:recyclerview:1.1.0:aar
androidx.cardview:cardview:1.0.0:aar
androidx.transition:transition:1.2.0:aar
androidx.browser:browser:1.0.0:aar
androidx.palette:palette:1.0.0:aar
androidx.mediarouter:mediarouter:1.0.0:aar
androidx.media:media:1.1.0:aar
com.google.android.material:material:1.1.0:aar
"

for spec in $ARTIFACTS; do
    group="${spec%%:*}"; rest="${spec#*:}"
    name="${rest%%:*}"; rest="${rest#*:}"
    version="${rest%%:*}"; type="${rest##*:}"
    path="$(echo "$group" | tr . /)/$name/$version"
    dest="$REPO/$path"
    file="$name-$version.$type"
    if [ -f "$dest/$file" ]; then
        continue
    fi
    mkdir -p "$dest"
    echo "fetch $group:$name:$version"
    curl -fsSL "$BASE/$path/$file" -o "$dest/$file"
done
echo "done -> $REPO"
