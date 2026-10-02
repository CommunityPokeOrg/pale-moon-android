# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

pref("startup.homepage_welcome_url", "about:home");
pref("startup.homepage_override_url", "about:home");
pref("app.vendorURL", "https://github.com/CommunityPokeOrg/pale-moon-android");
pref("browser.newtab.url", "about:blank");

// The desktop chrome's identity box requires this pref (normally set by
// the desktop brandings' shared preferences.inc).
pref("browser.identity.ssl_domain_display", 1);
