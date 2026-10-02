# Status

_Last updated: 2026-10-02 (**desktop Pale Moon XUL chrome bring-up**: `--enable-palemoon-desktop-chrome` now compiles the vendored `palemoon/` tree into the Android build and packages the desktop `browser.xul` chrome into the APK — replacing the Fennec mobile chrome for chrome name `browser`. On the emulator the desktop chrome **loads and executes**: `browser.xul` document load, all overlay scripts (browser.js, placesOverlay.xul, controller.js, InlineSpellChecker.jsm, etc.) compile and run, `OnChromeLoaded` fires, PM chrome components (nsBrowserGlue, sessionstore, fuel, feeds, downloads) and the Places backend register, `palemoon.js` + `newmoon-branding.js` prefs land in `defaults/pref`, and the OpenGL compositor initializes on the 1080x2209 surface. **Not yet verified: first paint of the chrome window** — the XUL doc finishes loading but no EndFrame ever reaches the BLAST SurfaceView (buffer stays `0x0`), so the screen still shows the Java shell over a blank content region; see the "Desktop chrome" section below.)_

_Previously (2026-10-02): **androidx migration landed**: the entire Java frontend was migrated off the legacy `android.support.*` libraries onto androidx (~38 AARs fetched from Google's maven repo into `$ANDROID_HOME/extras/androidx/m2repository`, resolved by `build/autoconf/android.m4` into `ANDROIDX_EXTRA_JARS`/`ANDROIDX_EXTRA_RES_DIRS`/`ANDROIDX_EXTRA_PACKAGES`). All jars compile, and the resulting APK now needs multidex — `MOZ_ANDROID_MIN_SDK_VERSION` was bumped 15→21 so D8 auto-partitions into `classes.dex`/`classes2.dex`/`classes3.dex` (the APK assembler and package manifest were updated to carry all dex files). Verified on the emulator: BrowserApp displays, TLS handshake + cert verification work, the OpenGL compositor initializes, and no class-loading failures occur. Gradle remains make-driven; the Gradle path is still unused.)_

_Previously (2026-10-01): APK rebranded to **New Moon** — package `org.palemoon.community`, label "New Moon", `newmoon-52.6.0` APK — installs, launches, and now **renders composited page content on-screen**: the presentation pipeline works end-to-end (raster → tiles → TextureHost → DrawQuad → EGL swap → BLAST surface → display), screenshot-verified with a red test page showing "RED TEST 123" under the Fennec chrome. Three separate surface-pipeline defects were root-caused and fixed; one interim workaround (on-top z-order) is documented below._

## Verified

- **Historical source recovered.** `vendor/uxp-android/` was extracted from
  UXP @ `63295d0087eb58a6eb34cad324c4c53d1b220491` — confirmed to contain the
  full pm4a surface: `mobile/android` (incl. `geckoview/`, branding
  `official`/`unofficial`), `widget/android`, `mozglue/android`, `gradle/`,
  `build/mobile`, `build/annotationProcessors`, `hal/android`,
  `dom/system/android`, `dom/gamepad/android`,
  `dom/media/platforms/android`, `dom/plugins/base/android`,
  `dom/xbl/builtin/android`, `image/decoders/icon/android`,
  `media/libyuv/util/android`, `media/webrtc/trunk/build/android`.
- **Android triples canonicalize.** `build/autoconf/config.sub` now maps
  `aarch64-linux-android`, `arm-linux-androideabi`, etc. (patch 0002).
- **NSPR cross-builds.** With `patches/0001-nspr-modern-android-ndk.patch`
  applied and Android NDK r27, `nsprpub` configures and compiles for
  `aarch64-linux-android` (API 21). Output: `libnspr4.so`, `libplc4.so`,
  `libplds4.so` — ELF 64-bit ARM aarch64 shared objects.
  Reproduce: `scripts/build-nspr-android.sh`.
- **Full-tree `./mach configure` completes** for
  `--enable-application=mobile/android --target=aarch64-linux-android`
  with `--enable-noncomm-build --enable-default-toolkit=cairo-android`,
  NDK r27.2 (unified LLVM toolchain, API 21), Android SDK 34
  (build-tools 34.0.0: aapt/aapt2/d8/aidl/zipalign/apksigner), JDK 17.
  Reproduce: `cp mozconfig/mozconfig.android-aarch64 upstream/uxp/mozconfig`,
  `export ANDROID_HOME=<sdk> ANDROID_NDK=<sdk>/ndk/27.2.12479018`,
  then `cd upstream/uxp && ./mach configure`. 917 moz.build files read,
  6206 descriptors, RecursiveMake + FasterMake backends generated.
- **`./mach build` completes end-to-end.** All C++ (incl. `libxul.so`,
  ~19 MB), `libmozglue.so` (shared, with `BionicGlue.cpp`), and all Java
  jars (gecko-browser, gecko-util, geckoview, sync/etc. restored from
  mozilla/gecko-dev esr52, stumbler, bouncer, constants, thirdparty)
  compile for aarch64-android. Fennec JNI wrappers were regenerated via
  `make -C obj-android-aarch64/mobile/android/base FennecJNIWrappers.cpp`
  then `make update-fennec-wrappers`.
- **`./mach package` produces a signed, installable APK:**
  `upstream/obj-android-aarch64/dist/newmoon-52.6.0.linux-android-aarch64.apk`
  (~33 MB, 1536 entries). Verified by inspection:
  - `lib/arm64-v8a/`: `libmozglue.so`, `libplugin-container.so` (Fennec
    layout: only the custom-linker loader libs live under lib/).
  - `assets/arm64-v8a/`: `libxul.so` + all NSS/NSPR/sqlite/etc. —
    extracted and loaded at runtime by mozglue's custom linker.
  - `classes.dex` + `classes2.dex` + `classes3.dex` (~10 MB total,
    produced by D8 with `--min-api 21` auto-multidex; the androidx
    frontend pushed the app past the 64K-method limit),
    `assets/omni.ja` (~6.4 MB, includes
    `chrome/chrome/content/browser.xul` + 38 XUL/XBL files —
    the full Fennec XUL frontend), 1183 `res/` drawables.
  - `apksigner verify --verbose --print-certs`: **Verifies** with
    v1+v2+v3 schemes (CN=Android Debug cert from `~/.android/debug.keystore`).
  - aapt badging: package `org.palemoon.community`, versionName
    `52.6.0`, minSdk 21, targetSdk 23; application-label "New Moon".

## What patch 0003 changes

- Restores `build/autoconf/android.m4` (modernized): `MOZ_ANDROID_NDK`,
  `MOZ_ANDROID_CPU_ARCH`, `MOZ_ANDROID_SDK` rewritten for unified LLVM NDK
  + modern SDK layout (d8/aapt2, `emulator/` dir); legacy support-AAR
  checks are gated off (those deps will come from androidx/Gradle later).
- Restores ~20 Android hunks in `old-configure.in` (toolchain flags,
  MOZ_LINKER, hash-style sysv, ANDROID_PACKAGE_NAME, gamepad, mozglue,
  TK_CFLAGS for `android` widget toolkit, `MOZ_ANDROID_SDK(34)` for
  `mobile/android`).
- Restores moz.build Android frontend machinery:
  `ANDROID_RES_DIRS`, `ANDROID_EXTRA_RES_DIRS`, `ANDROID_ASSETS_DIRS`,
  `ANDROID_EXTRA_PACKAGES`, `ANDROID_GENERATED_RESFILES`,
  `ANDROID_APK_NAME`, `ANDROID_APK_PACKAGE`,
  `ANDROID_INSTRUMENTATION_MANIFESTS` in `context.py`/`data.py`/
  `emitter.py`/`recursivemake.py`.
- `constants.py`: `Android` added to `OS` enum (required for
  `--enable-default-toolkit=cairo-android`).
- `java.configure`: `javah` optional (removed in JDK 10+);
  `javac_version` decoded as text.
- `icu.m4`: accepts clang as the ICU assembler (unified NDK has no GNU as
  and no yasm target flags on aarch64).
- `config/external/moz.build`: `modules/xz-embedded` builds when
  `MOZ_LINKER` (mozglue/linker needs it for szip APK decompression).
- `dom/base/moz.build`, `toolkit/modules/moz.build`: Android provides its
  own `SiteSpecificUserAgent.js` / `LightweightThemeConsumer.jsm` —
  gated like 2019's `MOZ_FENNEC` guards.
- `mobile/android`: GCM default off (no Play Services yet);
  `MOZ_NATIVE_DEVICES` unset; dead `imply_option`s removed; dead
  `mozilla.dtd` locale entries removed.
- New file `build/autoconf/android.m4` and `gradlew` shim live under
  `vendor/uxp-android/` (applied by overlay).

## What patch 0004 changes (build + packaging bring-up)

- `mozglue/build/moz.build`: builds `libmozglue.so` as a shared library on
  Android (was WINNT/Darwin only) and adds `BionicGlue.cpp`.
- `upload-files.mk`: `MOZ_PKG_FORMAT = APK` for the android widget toolkit;
  `upload-files-APK.mk` restored to vendor — drives
  `mozbuild.action.package_fennec_apk`.
- `old-configure.in`: `OMNIJAR_NAME = assets/omni.ja` when
  `MOZ_BUILD_APP=mobile/android` (required by the APK packager).
- `config/makefiles/java-build.mk` + `mobile/android/base/Makefile.in`
  (vendor): dexing switched from dx to **d8** (build-tools 34 has no dx;
  d8 needs an existing output dir and jar/class-file inputs).
- `config/android-common.mk` (vendor): `RELEASE_SIGN_ANDROID_APK` now does
  zipalign **then** `apksigner sign` with the standard debug keystore
  (v1+v2+v3); the old jarsigner path produced APKs that fail `apksigner
  verify` on API 15–20.
- `mobile/android` proguard cfgs (vendor): `-dontwarn com.google.android.gms.**`
  (play-services-ads 8.4.0 references WebSettings AppCache APIs removed in
  API 28).
- `python/mozbuild/mozpack/files.py`, `recursivemake.py`, `emitter.py`,
  `generate_browsersearch.py`: py3 str/bytes fixes for the packaging path.
- `config/config.mk`: `-static-libstdc++` for `OS_TARGET=Android` — the
  custom linker loads packaged .so files itself, so nothing may need
  `libc++_shared.so` (same approach as the 2019 port).
- `mobile/android/installer/package-manifest.in` (vendor):
  `libhunspell.so` added to `assets/` — it is a `NEEDED` dep of libxul
  and its absence aborted the libxul load.
- `mozglue/linker/XZStream.cpp`: `ParseUncompressedSize()` now sums **all**
  index records instead of reading only the first. Modern `xz -T` writes
  multi-block streams (4 blocks for libxul); only the first block's size
  was used, producing a 25 MB cache file for an 80 MB libxul → SIGBUS on
  segment mapping. Fixed file now decompresses fully (verified in logcat:
  `XZStream decoded 80352792`).
- `mozglue/linker/Elfxx.h`: aarch64 `R_AARCH64_ABS64/GLOB_DAT/JUMP_SLOT/
  RELATIVE` constants for the custom linker.
- Remaining C++ interface fixes across `dom/plugins/ipc`, `ipc/chromium`,
  `hal`, `widget`, `gfx`, `netwerk`, `security`, `toolkit`, `xpcom`,
  `memory/jemalloc`, `mozglue/linker` to reconcile the 2019 Android code
  with current UXP.
- API-34 javac collisions renamed in vendor:
  `RemotePresentationService.getDeviceId()` → `getPresentationDeviceId()`
  (clashes with `ContextWrapper.getDeviceId():int`), and
  `BouncerService.getDataDir()` → `getAppDataDir()` (clashes with
  `Context.getDataDir():File`).

## Environment dependencies (build machine)

- Android SDK 34 + NDK `27.2.12479018`, JDK 17.
- **ProGuard is no longer in the SDK.** A 6.2.0 `proguard.jar` must be at
  `$ANDROID_HOME/tools/proguard/lib/proguard.jar` (obtained here from the
  Ubuntu `libproguard-java` deb).
- `~/.android/debug.keystore` (alias `androiddebugkey`, pass `android`)
  is created automatically by the signing rule if absent.
- Vendored AARs under `$ANDROID_HOME/extras/{android,google}/m2repository/`
  (incl. play-services-*-8.4.0) — see `scripts/` for install steps.

## Runtime status (verified on emulator, Android 34 / x86_64 + ndk_translation)

AVD `nocturne-emu` (google_apis x86_64, abi list includes arm64-v8a via
ndk_translation). No /dev/kvm → TCG software CPU, cold boot ~8 min.

- `adb install -r dist/newmoon-52.6.0.linux-android-aarch64.apk`: succeeds
  (`adb install` itself is flaky on this emulator; `adb push` to
  `/data/local/tmp/` + `pm install -r` is reliable).
- `am start -n org.palemoon.community/.App`: **the app launches.**
  Java frontend verified working end-to-end: LauncherActivity → BrowserApp,
  profile migration, preferences, network listener, search engine manager,
  and the home screen UI renders (GLES/EGL).
- mozglue's custom linker on aarch64 works: decompresses every xz'd
  library (incl. 80 MB libxul), resolves all relocations
  (`ABS64/GLOB_DAT/JUMP_SLOT/RELATIVE`), loads NSS/NSPR/sqlite/hunspell/etc.,
  and begins running libxul's C++ static initializers.
- `MOZ_LINKER_ONDEMAND=0` (eager page mapping) is required on this
  emulator — without it the run dies earlier with `SEGV_ACCERR` on the
  main thread; the fault-handler-based lazy-page path is untested on
  real arm64 hardware.
- **The app reaches steady state.** `XRE_mainRun` completes end to end:
  omni.ja component/xpt registration, directory-provider startup, chrome
  manifest registration, profile prefs, `profile-after-change`, chrome
  window creation via `nsWindowWatcher::OpenWindow` (`browser.xul`
  loads — `nsWebShellWindow::JustCreateWebShell` → docshell →
  `CreateAboutBlankContentViewer` → XPConnect globals wrapped →
  `loadURI` rv=0), hidden window, `final-ui-startup`,
  `appstartup-run`, and the Gecko event loop then idles in
  `epoll_wait`. Verified on cold (`pm clear`) and warm launches; the
  warm launch renders Top Sites with real bookmark data (profile DB
  works). Screenshot-verified, not just logcat.
- The earlier `SIGSEGV@0` in libxul static-init was actually two
  packaging/config bugs, both now fixed (see below); the stagefright
  frame turned out to be a red herring (first `.init_array` entry to
  trip the pref service, not the culprit).
- Remaining emulator issue (environmental): `system_server` and the app
  both ANR under ndk_translation load during startup
  ("Timed out while trying to bind" / broadcast timeouts on
  `MY_PACKAGE_REPLACED`). The ANR dialogs block input dispatch, so
  interactive verification (typing a URL, clicking links) is not
  possible on this emulator. system_server keeps making progress
  (not deadlocked); a real arm64 device is unlikely to exhibit this.
- **XUL pipeline verified on-device.** The profile's startupCache
  contains `xulcache/…/chrome/content/browser.xul` (the chrome XUL was
  parsed and its prototype cached) plus `xblcache/` entries for toolkit
  bindings — XUL parsing, the prototype cache, and the XBL binding
  engine all execute correctly.
- **Real web page loads verified end-to-end (2026-10-01).** After
  fixing the libxul logging blackout (see root causes), the earlier
  "navigations never start" conclusion proved to be an observability
  artifact, not a functional failure. Verified via `am start -a VIEW`:
  - `http://neverssl.com` — full navigation lifecycle:
    `START → TITLE → LOCATION_CHANGE → SECURITY_CHANGE → PAGE_SHOW →
    STOP → FAVICON → THUMBNAIL`, including a followed HTTP redirect
    chain (neverssl.com → fineolduniquesong.neverssl.com/online).
  - `https://example.com` — same full cycle including
    `SECURITY_CHANGE` (NSS/PSM path works; TLS handshake + cert
    verification complete, ~48 s wall-clock under ndk_translation).
  The first-ever HTTPS attempt appeared to stall at `START` for
  several minutes — first-use NSS/certdb initialization under
  translation is extremely slow; a subsequent run completed normally.
- **Internal rendering verified via captured thumbnail (2026-10-01).**
  `browser.db`'s `thumbnails` table holds real PNGs produced by the
  thumbnail pipeline: the extracted `https://example.com` capture
  (441x368 RGBA) shows correctly laid-out, text-shaped page content —
  layout, text shaping, and paint all work inside Goanna. The visible
  LayerView surface was still blank at that point, so the remaining
  gap is presenting composited frames to the SurfaceView, not
  rendering.
- **Compositor/presentation verified on-screen (2026-10-01).** A
  `file:///` test page with a solid red background and large text
  renders on the device: screencap shows the red page with
  "RED TEST 123" glyphs composited by Goanna under the Fennec chrome
  (URL bar, tab counter). The full chain works: `EndFrame` GL
  readbacks inside `CompositorOGL` show the real frame pixels
  (`center=ff0000ff`), `eglSwapBuffers` succeeds on the EGLSurface
  bound to the java `Surface`, buffers latch into the in-scene
  `SurfaceView[...](BLAST)` layer (`activeBuffer` populated,
  `dequeueTime` tracking frames), and the display shows them. Three
  defects were root-caused and fixed to get here (see root causes
  6–8); the remaining presentation caveat is the interim on-top
  z-order (see caveats).
- **targetSdk=24 verified installed.** `pm install` of the rebuilt APK
  on the Android 34 emulator reports `minSdk=15 targetSdk=24`. The
  system still shows `DeprecatedTargetSdkVersionDialog` (it fires for
  targetSdk < the notice threshold, ~API 31 on A14), but unlike the
  earlier wedge it IS dismissible via `input tap` — at real display
  coordinates (1080x2400, not scaled screenshot space): the OK button
  at roughly (898,1461) dismisses it and focus returns to BrowserApp.
  The coordinate-scaling detail explains earlier 'input doesn't work'
  observations.
- **All observed chrome JS errors resolved.** After `browser.xul`
  loads, the GeckoConsole bridge showed a cascade of JS errors — every
  one root-caused and fixed (see root causes): unpreprocessed
  `browser.js`, missing `Services.androidBridge`/`Services.telemetry`
  getters, `UITelemetry` module absent, parental-controls
  `NOT_AVAILABLE`, missing tracking-protection prefs, stale
  `storage-mozStorage.js` contract+manifest entries, unpackaged
  `blocklist.manifest`, and unguarded imports of modules
  (`ExtensionContent`, `PresentationDeviceInfoManager`,
  `SimpleServiceDiscovery`) that UXP no longer ships. Remaining
  console noise is cosmetic: `GMPInstallManager.jsm` lazy import
  (`MOZ_GMP` unset), `ua-update.json` profile-path lookup, a dead
  snippets.mozilla.net endpoint, and Cu.import failure lines logged
  (but caught) by the guarded stubs.
- Emulation caveat: everything above runs under ndk_translation
  (arm64→x86_64). `lldb-server`/gdbserver cannot run inside it, so
  native debugging is limited to logcat instrumentation.

## Runtime root causes found and fixed (this bring-up)

1. **Omnijar never initialized on Android** — `XRE_InitCommandLine` in
   `toolkit/xre/nsAppRunner.cpp` only calls `mozilla::Omnijar::Init`
   when `UXP_CUSTOM_OMNI` is set; esr52 processed `-greomni`
   unconditionally. Without it the gre `omni.ja`'s
   `chrome.manifest`/`components.manifest`/xpt never register → every
   XPConnect wrap fails → the first content window cannot be created.
   Fixed with a `MOZ_WIDGET_ANDROID` conditional (patch 0004).
2. **`goanna.js` missing from packaged omni.ja** —
   `mobile/android/installer/package-manifest.in` still listed esr52's
   `@BINPATH@/greprefs.js`; UXP renamed it to `goanna.js`. The packager
   only warns about missing manifest entries, so this was silent in the
   log. Missing goanna.js → `pref_ReadPrefFromJar` fails →
   `Preferences::Init` fails → `gCacheData`/`gObserverTable` never
   allocated → `SIGSEGV@0` in `AddBoolVarCache` during
   `nsIOService::Init`. Fixed by renaming the manifest entry (in
   `vendor/uxp-android/mobile/android/installer/package-manifest.in`).
3. **All libxul logging was dead** — the largest single debugging
   root cause of this port. libxul exports its own
   `__android_log_print`/`__android_log_write`/`__android_log_vprint`/
   `__android_log_assert` (`T`, `@@xul6`-versioned) from the bundled
   stagefright liblog (`media/libstagefright/system/core/liblog/
   logd_write.c`, `FAKE_LOG_DEVICE=True` in moz.build). That stub
   writes to `/dev/log/*` (removed since Android L) and falls back to
   stderr — which is `/dev/null` in the app — so **every** libxul-side
   `__android_log_print`, `MOZ_LOG`, and MOZ_ASSERT message was
   silently discarded while Java-side logging looked fine. This is why
   "nothing Gecko-side happened after runGecko" looked real.
   `mozglue/linker/ElfLoader.cpp:30` explicitly warns about bundled
   stub `__android_log_*` implementations. Fixed by dlopening the real
   `liblog.so` inside the stub on `__ANDROID__` and forwarding
   `__android_log_buf_write`/`__android_log_bwrite` (dlopen inside
   libxul routes through `__wrap_dlopen` → `SystemElf` → real dlopen).
   Verified: PM* instrumentation, `GeckoConsole`, `MOZ_LOG` module
   output (e.g. `nsScreenManagerAndroid`) now all reach logcat.
4. **`browser.js` shipped unpreprocessed** — vendored `jar.mn` lacked
   the `*` marker, so literal `#ifdef MOZ_SAFE_BROWSING` lines shipped
   in the chrome → SyntaxError → `BrowserApp` undefined → startup dead
   after window creation. Fixed by marking `browser.js` preprocessed
   in `mobile/android/chrome/jar.mn`.
5. **Missing XPConnect glue / services that esr52-era chrome expects:**
   `Services.androidBridge` (added to `Services.jsm` initTable under
   `MOZ_WIDGET_ANDROID`; `nsAndroidBridge` factory was already
   registered in `widget/android/nsWidgetFactory.cpp`), `Services.
   telemetry` (no-op getter — no nsITelemetry exists in UXP, but
   `SessionStore.js` calls `getHistogramById`), `UITelemetry.jsm`
   (new module implementing `nsIUITelemetryObserver` — start/stop/
   addEvent; the Java→native `widget::Telemetry` observer path routes
   back into it), `nsIParentalControlsService::IsAllowed` returning
   `NS_ERROR_NOT_AVAILABLE` on Android (aborted `BrowserApp.startup`
   mid-way; now returns allowed under `ANDROID` — no Android
   restriction provider exists), missing
   `privacy.trackingprotection.{enabled,pbmode.enabled}` default prefs
   (`getTrackingMode` threw; added to `mobile.js`), and packaging
   drift: `storage-json.js`/`blocklist.manifest` absent from
   `package-manifest.in` (login storage + addon-manager startup
   failed), plus unguarded imports of modules UXP deleted
   (`ExtensionContent` — killed the entire `content.js` frame script,
   `PresentationDeviceInfoManager`, `SimpleServiceDiscovery` —
   replaced with a lazy stub so casting code no-ops cleanly).
6. **Cross-allocator free in `nsDataHandler::ParseURI`** —
   `netwerk/protocol/data/nsDataHandler.cpp` `malloc`'d via
   `PL_strndup` (scudo on Android) and released with jemalloc `free()`
   → deterministic SIGSEGV inside `data:`/`file:` URI handling after
   first paint. Fixed: `free(buffer)` → `PL_strfree(buffer)`.
   Verified: process survives indefinitely past the first page.
7. **SurfaceView layer subtree orphaned by a BLAST sync timeout** —
   on BLAST-era Android the `SurfaceView`/`(BLAST)`/`Background for
   SurfaceView` layers were all in SurfaceFlinger's *orphan* list
   (verified via `dumpsys SurfaceFlinger`), so correctly-swapped
   buffers latched into a dead layer and the screen showed only the
   app window. `logcat` showed `BLASTSyncEngine: Sync group N
   timeout — Unfinished container: ActivityRecord{.../.App}`: the WMS
   blast-sync timed out while the app's UI thread (== the Gecko main
   thread) was still busy ~5 min in libxul init under ndk_translation.
   Fix (Java): `LayerView.updateCompositor` force-recreates the
   surface once (`setVisibility(GONE)` + posted `VISIBLE`) before
   first compositor creation so WMS registers a live subtree — the
   recreated `SurfaceView` layers land in the scene graph (verified).
8. **`CompositorOGL::Resume()` never renewed the EGL surface on
   Android** — the `gl()->RenewSurface()` call was gated
   `#if defined(MOZ_WIDGET_UIKIT)` (iOS-only). After every surface
   destroy/create cycle (background→foreground, rotation, the forced
   recreate) the compositor kept swapping into the stale
   `EGLSurface`/`ANativeWindow` → the new in-scene BLAST queue stayed
   empty (`activeBuffer=[0x0]`) while `eglSwapBuffers` still returned
   success. Enabled the renew path for `MOZ_WIDGET_ANDROID`:
   `RenewSurface` → `CreateSurfaceForWindow` re-reads the current
   java `Surface` (`GET_JAVA_SURFACE`) and builds a fresh
   `ANativeWindow` + `EGLSurface` — verified by `GeckoEGL` logs and
   buffers latching into the *new* BLAST layer after resume.

## Desktop Pale Moon chrome (`--enable-palemoon-desktop-chrome`)

Goal: ship the desktop Pale Moon XUL chrome (vendored `palemoon/` tree)
as the app chrome on Android instead of the Fennec mobile chrome.

**Mechanics (all verified in-tree):**

- `build/autoconf/android.m4`: `MOZ_ARG_ENABLE_BOOL` →
  `MOZ_PALEMOON_DESKTOP_CHROME` + `AC_SUBST`; registered in
  `build/moz.configure/old.configure` `@old_configure_options`.
- `mobile/android/app.mozbuild`: under the flag, DIRS gains
  `/palemoon/app`, `/palemoon/base`, `/palemoon/components`,
  `/palemoon/locales`, `/palemoon/modules`, `/palemoon/themes`.
  `palemoon/app/moz.build` ships prefs/profile bits but its desktop
  `GeckoProgram` and all non-Android-safe pieces are gated on
  `OS_TARGET != 'Android'`; `palemoon/app/Makefile.in` `libs::`
  desktop-binary steps are likewise gated. `palemoon/components`
  builds into libxul (`FINAL_LIBRARY='xul'`, module renamed
  `nsPalemoonCompsModule` to avoid the toolkit collision) with the
  directory provider, feeds, and shell-service subdirs enabled.
- `package-manifest.in`: under the flag, `browser.jar` +
  `browser.manifest` replace `chrome.jar` (the three PM jar.mn trees —
  base, locales, themes — all merge into `browser.jar`); `palemoon.js`
  + `newmoon-branding.js` land in `defaults/pref`; PM chrome JS
  components (BrowserComponents.manifest, nsBrowserGlue,
  nsSessionStartup/Store, fuel, status4evar, feeds, downloads,
  nsAboutRedirector, nsBrowserContentHandler) and their `.xpt`s are
  packaged; the Places backend JS components +
  `toolkitplaces.manifest` + `places.xpt` are included (required by
  PlacesUtils.jsm / placesOverlay.xul — without them the chrome fails
  with `Ci.nsINavHistoryResultNode is undefined`).
- `mobile/android/moz.build` + `mobile/android/components/moz.build`
  gate the Fennec chrome jar and the mobile chrome-JS components under
  the flag (mobile chrome jar is still produced but no longer
  registered for `browser`).
- New branding bits: `mobile/android/branding/newmoon/locales/en-US/
  browserconfig.properties` (homepage = about:home; palemoon.js points
  `browser.startup.homepage` at
  `chrome://branding/locale/browserconfig.properties`) and
  `pref/newmoon-branding.js` (`startup.homepage_welcome_url` etc.).

**Verified (emulator, Android 34 x86_64 + ndk_translation):**

- `./mach build && ./mach package` produce a signed 38.9 MB
  `newmoon-52.6.0.linux-android-aarch64.apk` (apksigner-verified,
  installs via `pm install -r`).
- omni.ja contains desktop `chrome/browser/content/browser/*` (322
  files), `chrome/en-US/locale/browser/*`, skin `classic/1.0`,
  merged `chrome.manifest`/`components.manifest`/`interfaces.xpt`,
  and all PM + Places components; zero Fennec `chrome/chrome/` entries.
- Runtime (logcat pid of `org.palemoon.community`): XRE brings up the
  top window at `chrome://browser/content/browser.xul`,
  `StartDocumentLoad` + `OnChromeLoaded` fire, every overlay script
  compiles and executes (`CloneAndExecuteScript ok=1` for dozens of
  scripts incl. InlineSpellChecker.jsm via the JS component loader),
  `PMCOMP CreateCompositor w=1080 h=2209` + EGL surface + "OpenGL
  compositor Initialized Succesfully" (SwiftShader ES 3.0). The
  process stays alive at steady state after scripts complete.
- Fixed en route: browser.manifest packaging (chrome package
  registration), palemoon/app DIRS inclusion (default prefs), Places
  component packaging (nsINavHistoryResultNode XPT), blocklist/
  ua-update.json manifest collision with mobile/android's own copies,
  desktop-exe Makefile steps on Android.

**Not verified / current blocker:**

- **No first paint of the chrome window.** After scripts finish, the
  process idles with nothing latched to the BLAST SurfaceView
  (`buffer=0x0`, `size=(0,0)`, `TransparentRegion count=0`); no
  `EndFrame`/`NeedsPaint` activity for the chrome widget. Screen shows
  the Java shell (URL bar) over a blank region. The tab content widget
  (type=4) reports `needsPaint=0`, `lm=0x0` — its layer manager is
  never created. Whether the chrome document builds its frame tree /
  refresh driver ticks, or desktop `browser.js` startup stalls before
  first reflow, is the next thing to instrument (the recurring
  system_server ANR dialog also keeps overlaying the screen under
  ndk_translation and may starve frame delivery).
- Residual non-fatal errors: `browser-clh` contract→CID warning
  (Fennec's `be623d20` BrowserCLH CID stays in merged
  components.manifest while its impl is excluded — benign), the
  `browser.startup.homepage`/`startup.homepage_welcome_url`
  FILE_NOT_FOUND fixed by the new branding files above, a moz-icon
  gtk warning, and a GMPInstallManager lazy-import failure.
- Interactivity is entirely unadapted (menubar→Android, window.open,
  hover, keyboard shortcuts, toolbox layout at phone width); see
  docs/XUL-ON-ANDROID.md for the mapping assessment.

## Unverified / partial (honest caveats)

- **User interaction mostly unverified.** Dismissing the system
  deprecated-SDK dialog via `input tap` works (at real display
  coordinates), but a swipe on the app's own content area triggered an
  input-dispatch ANR — consistent with the emulator's overall wedge
  under ndk_translation load (system_server also ANRs at the same
  time), not necessarily an app bug. Typing a URL / tapping a link
  remains untested; needs a real arm64 device or a KVM host.
- **Compositor depth is partially verified.** `nsWindow`,
  `nsAppShell`, the docshell/viewer path, and full tab lifecycle
  events all execute; the extracted tab thumbnail proves pages are
  genuinely rasterized (layout+paint work).
- **Paint pipeline verified end-to-end (2026-10-01).**
  Android-gated logcat probes across the whole layers stack show the
  full pipeline executing every frame:
  `FrameLayerBuilder::DrawPaintedLayer` paints the real display items
  (items=2, full-viewport 1080x2083 dirty rect) into the multi-tiled
  `ClientMultiTiledLayerBuffer`; all 15 512x512 tiles pass
  `ValidateTile` with live borrowed DrawTargets; IPC delivers
  `UseTiledLayerBuffer` (res=1.0, 15 textured tiles); the compositor
  deserializes real `BufferTextureHost`s per tile and
  `TiledContentHost::RenderTile` binds TextureSources + issues
  `DrawQuad` for all 15 tiles each composited frame. A red-background
  test page produces the identical trace — rasterization, tiling,
  IPC, and quad emission all work. The earlier suspects (texture
  upload, quad culling) were exonerated: `EndFrame` GL readbacks show
  correct pixels, and the pixel loss turned out to be entirely in
  SurfaceFlinger registration/z-order (root causes 7–8 above).
  Separately fixed: ndk_translation ANR storms were caused by guest
  `mprotect` → `FlushGuestCodeCache` mutex storms — mitigated by
  disabling JS JIT tiers + `MALLOC_OPTIONS` env.
- **Interim workaround: surface composites ON TOP of the window.**
  With the normal below-window ordering, the recreated in-scene
  BLAST layer correctly latches frames (verified) but the display
  still shows the app window's pixels in the content region: the
  transparent-region "hole punch" the SurfaceView should carve in
  the window surface is never applied on this stack
  (`TransparentRegion count=0` in the SF dump for both this app and
  a minimal working control app — and the control app works, so the
  window-side cover is what differs; a white windowBackground was
  ruled out by switching it to transparent with no change). As an
  interim, `LayerSurfaceView` uses `setZOrderOnTop(true)`, which is
  verified to display Goanna-composited content correctly. Known
  consequence: UI drawn inside the app window *over* the content
  area (tabs-panel drawer, form-assist popup, text-selection
  handles) is covered by the surface; popup *windows* (menus,
  doorhangers) are unaffected. Proper fix candidates: get the
  window transparent-region punch applied, or complete the
  (upstream-disabled) TextureView path which composites in-window.
- **Rebranded to unofficial "New Moon" identity** (2026-10-01):
  `MOZ_APP_BASENAME=NewMoon`, `MOZ_APP_VENDOR=Moonchild`,
  `ANDROID_PACKAGE_NAME=org.palemoon.community`, display name
  "New Moon" — per Pale Moon's TRADEMARK notice, official "Pale Moon"
  branding requires Moonchild permission and this is a community port.
  `MOZ_APP_ID` now uses Pale Moon's real GUID
  `{8de7fcbb-c55c-4fbe-bfc5-fc555c87dbc4}` + `UXP_APPCOMPAT_GUID=1` so
  Pale Moon-targeted extensions/themes install without compat hacks;
  `MOZ_APP_UA_NAME=Palemoon`. New branding dir
  `vendor/uxp-android/mobile/android/branding/newmoon/` with generated
  crescent-moon launcher/favicon/about assets. Verified in the built
  APK: aapt badging `org.palemoon.community` / label "New Moon",
  brand.properties in omni.ja.
  **Gotcha:** after changing `confvars.sh`, `mobile/android/base`
  generated sources regenerate but `classes.dex` can stay stale —
  `javac` constant-folds `AppConstants.ANDROID_PACKAGE_NAME` into
  `content://` URIs, and a stale fold produced
  `content://org.mozilla.fennec_ubuntu.db.browser` SecurityExceptions
  on first launch (provider permission denials, fatal
  `GeckoBackgroundThread` crash). Fix: delete
  `objdir/mobile/android/base/{generated,*classes*,*.jar,classes.dex}`
  and rebuild + repackage. Verified: 0 `fennec_ubuntu` literals in the
  new dex, clean launch under pid of the new package.
- Signed with the auto-generated **debug** key only.
- The UI is the **Fennec-derived pm4a mobile frontend** (XUL/XBL chrome:
  `browser.xul` + bindings inside omni.ja) on the full Goanna/UXP
  platform — not the desktop Pale Moon browser chrome. XUL does map to
  Android here: the XUL/XBL frontend ships, its window instantiates at
  runtime, and the chrome JS runs — the gap to "full Pale Moon UI" is
  the chrome content itself (mobile chrome vs `browser/` desktop
  chrome), not the XUL platform.
- Support-library AAR `extra_jars` that resolve to `None` are still
  filtered in the backend; androidx/Gradle frontend rework not done.
  (Superseded: androidx now resolved via `ANDROIDX_EXTRA_JARS`.)
- AndroidX migration verified on-device (2026-10-02): multidex APK
  installs and launches; BrowserApp displays, TLS + compositor + tabs
  all work; no ClassNotFound/VerifyError. The legacy
  play-services AARs remain compile-time-only (not bundled), so cast/
  install-referrer features are stubs — by design.
- `ANDROID_TOOLS` maps to the SDK `emulator/` dir (no `tools/` dir in
  modern SDKs).
- Two benign packaging warnings remain: "nothing matches overlay file
  `sync_avatar_default.png`/`sync_promo.png`" — the drawables still land
  in the APK.
- Crash-path diagnostics remain in the tree (Android-gated):
  `mozglue/linker/ElfLoader.cpp` (`moz_pmlog` export),
  `mfbt/Assertions.cpp` (assert → logcat), `memory/mozalloc` abort →
  logcat. They log only on crashes/fatals and are worth keeping until
  first interactive use is stable; all temporary instrumentation has
  been removed.

## Known missing pieces (next work)

1. ~~Fix content presentation to LayerView~~ — **done** (2026-10-01):
   composited page content reaches the display (root causes 7–8 +
   on-top interim). Remaining polish: restore below-window ordering
   (transparent-region punch or TextureView) so in-window overlays
   aren't covered by the content surface.
2. **Interactive verification on a real arm64 device** (or a faster
   emulator host): page loads via intent are verified (HTTP + HTTPS
   with full tab lifecycle); remaining is *interactive* use — typing
   URLs, tapping links — blocked on this emulator by ANR wedges; watch
   for ndk_translation-specific behavior that won't reproduce on
   hardware.
2. ~~Pale Moon branding/product pass~~ — done (unofficial "New Moon"
   branding + Pale Moon app GUID/UA); official "Pale Moon" branding
   needs Moonchild's permission and remains available via
   `MOZ_OFFICIAL_BRANDING_DIRECTORY`.
3. ~~Java frontend androidx migration~~ — **done** (2026-10-02):
   all `android.support.*` references rewritten to androidx (~80-rule
   migration script, `scripts/migrate-androidx.py`), support libs
   replaced by ~38 androidx AARs (`scripts/fetch-androidx.sh`),
   multidex enabled via minSdk 21, all three dex files packaged.
   Remaining in this area: Gradle 8 build path (make-driven
   javac/aapt2/D8 still does the build; `gradle/` is vestigial),
   targetSdk 23→34 (requires runtime-permission handling), and a
   stale `android.support.v4.app.Fragment` keep in proguard.cfg.
4. **First paint of the desktop chrome window** (see the Desktop
   chrome section): instrument why the loaded `browser.xul` document
   never issues a frame (refresh driver / frame-tree build vs.
   `browser.js` startup stall vs. emulator starvation), then fix.
   After that: Android-ize the desktop chrome's interaction model
   (menubar→overflow menu, no hover/keyboard deps, toolbox layout at
   phone width).
5. Release signing path + l10n/crashreporter overrides audit.
