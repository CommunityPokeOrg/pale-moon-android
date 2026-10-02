#!/usr/bin/env python3
"""Rewrite android.support.* references to androidx.* in the vendored
mobile/android Java sources and layout XMLs.

Class-level mapping of the 2016 Fennec frontend to the androidx package
layout (core 1.1.0 era). Applied to every *.java under mobile/android and
to widget class names in layout/*.xml. Strings like
android.support.customtabs.action.CustomTabsService (intent actions kept
literal by androidx for compat) and android.support.PARENT_ACTIVITY /
android.support.FILE_PROVIDER_PATHS meta-data names are untouched because
only java/xml-tag contexts are rewritten.
"""
import os
import re
import sys

# Longest-prefix-first rules: dotted prefix -> dotted prefix.
RULES = [
    ('android.support.customtabs.', 'androidx.browser.customtabs.'),
    ('android.support.multidex.', 'androidx.multidex.'),

    ('android.support.design.widget.NavigationView',
     'com.google.android.material.navigation.NavigationView'),
    ('android.support.design.widget.Snackbar',
     'com.google.android.material.snackbar.Snackbar'),
    ('android.support.design.widget.BaseTransientBottomBar',
     'com.google.android.material.snackbar.BaseTransientBottomBar'),
    ('android.support.design.widget.BottomSheetBehavior',
     'com.google.android.material.bottomsheet.BottomSheetBehavior'),
    ('android.support.design.widget.BottomSheetDialog',
     'com.google.android.material.bottomsheet.BottomSheetDialog'),
    ('android.support.design.widget.BottomSheetDialogFragment',
     'com.google.android.material.bottomsheet.BottomSheetDialogFragment'),
    ('android.support.design.widget.TextInputLayout',
     'com.google.android.material.textfield.TextInputLayout'),
    ('android.support.design.widget.TextInputEditText',
     'com.google.android.material.textfield.TextInputEditText'),
    ('android.support.design.widget.FloatingActionButton',
     'com.google.android.material.floatingactionbutton.FloatingActionButton'),
    ('android.support.design.widget.TabLayout',
     'com.google.android.material.tabs.TabLayout'),
    ('android.support.design.widget.AppBarLayout',
     'com.google.android.material.appbar.AppBarLayout'),
    ('android.support.design.widget.CollapsingToolbarLayout',
     'com.google.android.material.appbar.CollapsingToolbarLayout'),
    ('android.support.design.widget.CoordinatorLayout',
     'androidx.coordinatorlayout.widget.CoordinatorLayout'),
    ('android.support.design.R', 'com.google.android.material.R'),
    ('android.support.design.', 'com.google.android.material.'),

    ('android.support.v7.media.', 'androidx.mediarouter.media.'),
    ('android.support.v7.graphics.Palette', 'androidx.palette.graphics.Palette'),
    ('android.support.v7.app.NotificationCompat', 'androidx.core.app.NotificationCompat'),
    ('android.support.v7.app.AppCompatDelegateImplV7', 'androidx.appcompat.app.AppCompatDelegateImpl'),
    ('android.support.v7.app.', 'androidx.appcompat.app.'),
    ('android.support.v7.view.', 'androidx.appcompat.view.'),
    ('android.support.v7.content.res.', 'androidx.appcompat.content.res.'),
    ('android.support.v7.text.', 'androidx.appcompat.text.'),
    ('android.support.v7.widget.helper.', 'androidx.recyclerview.widget.helper.'),
    ('android.support.v7.widget.CardView', 'androidx.cardview.widget.CardView'),
    ('android.support.v7.widget.RecyclerView', 'androidx.recyclerview.widget.RecyclerView'),
    ('android.support.v7.widget.LinearLayoutManager', 'androidx.recyclerview.widget.LinearLayoutManager'),
    ('android.support.v7.widget.GridLayoutManager', 'androidx.recyclerview.widget.GridLayoutManager'),
    ('android.support.v7.widget.StaggeredGridLayoutManager', 'androidx.recyclerview.widget.StaggeredGridLayoutManager'),
    ('android.support.v7.widget.DefaultItemAnimator', 'androidx.recyclerview.widget.DefaultItemAnimator'),
    ('android.support.v7.widget.SimpleItemAnimator', 'androidx.recyclerview.widget.SimpleItemAnimator'),
    ('android.support.v7.widget.DividerItemDecoration', 'androidx.recyclerview.widget.DividerItemDecoration'),
    ('android.support.v7.widget.LinearSnapHelper', 'androidx.recyclerview.widget.LinearSnapHelper'),
    ('android.support.v7.widget.PagerSnapHelper', 'androidx.recyclerview.widget.PagerSnapHelper'),
    ('android.support.v7.widget.', 'androidx.appcompat.widget.'),
    ('android.support.v7.util.', 'androidx.recyclerview.widget.'),
    ('android.support.v7.appcompat.', 'androidx.appcompat.'),

    ('android.support.v4.animation.', 'androidx.core.animation.'),
    ('android.support.v4.app.LoaderManager', 'androidx.loader.app.LoaderManager'),
    ('android.support.v4.app.ActionBarDrawerToggle', 'androidx.appcompat.app.ActionBarDrawerToggle'),
    ('android.support.v4.app.Fragment', 'androidx.fragment.app.Fragment'),
    ('android.support.v4.app.FragmentActivity', 'androidx.fragment.app.FragmentActivity'),
    ('android.support.v4.app.FragmentManager', 'androidx.fragment.app.FragmentManager'),
    ('android.support.v4.app.FragmentTransaction', 'androidx.fragment.app.FragmentTransaction'),
    ('android.support.v4.app.FragmentPagerAdapter', 'androidx.fragment.app.FragmentPagerAdapter'),
    ('android.support.v4.app.FragmentStatePagerAdapter', 'androidx.fragment.app.FragmentStatePagerAdapter'),
    ('android.support.v4.app.FragmentTabHost', 'androidx.fragment.app.FragmentTabHost'),
    ('android.support.v4.app.FragmentHostCallback', 'androidx.fragment.app.FragmentHostCallback'),
    ('android.support.v4.app.FragmentController', 'androidx.fragment.app.FragmentController'),
    ('android.support.v4.app.FragmentManagerNonConfig', 'androidx.fragment.app.FragmentManagerNonConfig'),
    ('android.support.v4.app.DialogFragment', 'androidx.fragment.app.DialogFragment'),
    ('android.support.v4.app.ListFragment', 'androidx.fragment.app.ListFragment'),
    ('android.support.v4.app.', 'androidx.core.app.'),
    ('android.support.v4.content.Loader', 'androidx.loader.content.Loader'),
    ('android.support.v4.content.AsyncTaskLoader', 'androidx.loader.content.AsyncTaskLoader'),
    ('android.support.v4.content.CursorLoader', 'androidx.loader.content.CursorLoader'),
    ('android.support.v4.content.LocalBroadcastManager', 'androidx.localbroadcastmanager.content.LocalBroadcastManager'),
    ('android.support.v4.content.WakefulBroadcastReceiver', 'androidx.legacy.content.WakefulBroadcastReceiver'),
    ('android.support.v4.content.res.', 'androidx.core.content.res.'),
    ('android.support.v4.content.pm.', 'androidx.core.content.pm.'),
    ('android.support.v4.content.', 'androidx.core.content.'),
    ('android.support.v4.view.ViewPager', 'androidx.viewpager.widget.ViewPager'),
    ('android.support.v4.view.PagerAdapter', 'androidx.viewpager.widget.PagerAdapter'),
    ('android.support.v4.view.PagerTabStrip', 'androidx.viewpager.widget.PagerTabStrip'),
    ('android.support.v4.view.PagerTitleStrip', 'androidx.viewpager.widget.PagerTitleStrip'),
    ('android.support.v4.view.accessibility.', 'androidx.core.view.accessibility.'),
    ('android.support.v4.view.animation.', 'androidx.interpolator.view.animation.'),
    ('android.support.v4.view.inputmethod.', 'androidx.core.view.inputmethod.'),
    ('android.support.v4.view.', 'androidx.core.view.'),
    ('android.support.v4.widget.CursorAdapter', 'androidx.cursoradapter.widget.CursorAdapter'),
    ('android.support.v4.widget.SimpleCursorAdapter', 'androidx.cursoradapter.widget.SimpleCursorAdapter'),
    ('android.support.v4.widget.ResourceCursorAdapter', 'androidx.cursoradapter.widget.ResourceCursorAdapter'),
    ('android.support.v4.widget.SwipeRefreshLayout', 'androidx.swiperefreshlayout.widget.SwipeRefreshLayout'),
    ('android.support.v4.widget.DrawerLayout', 'androidx.drawerlayout.widget.DrawerLayout'),
    ('android.support.v4.widget.SlidingPaneLayout', 'androidx.slidingpanelayout.widget.SlidingPaneLayout'),
    ('android.support.v4.widget.', 'androidx.core.widget.'),
    ('android.support.v4.util.SimpleArrayMap', 'androidx.collection.SimpleArrayMap'),
    ('android.support.v4.util.ArrayMap', 'androidx.collection.ArrayMap'),
    ('android.support.v4.util.ArraySet', 'androidx.collection.ArraySet'),
    ('android.support.v4.util.SparseArrayCompat', 'androidx.collection.SparseArrayCompat'),
    ('android.support.v4.util.LongSparseArray', 'androidx.collection.LongSparseArray'),
    ('android.support.v4.util.CircularArray', 'androidx.collection.CircularArray'),
    ('android.support.v4.util.CircularIntArray', 'androidx.collection.CircularIntArray'),
    ('android.support.v4.util.LruCache', 'androidx.collection.LruCache'),
    ('android.support.v4.util.', 'androidx.core.util.'),
    ('android.support.v4.graphics.drawable.', 'androidx.core.graphics.drawable.'),
    ('android.support.v4.graphics.', 'androidx.core.graphics.'),
    ('android.support.v4.net.', 'androidx.core.net.'),
    ('android.support.v4.os.', 'androidx.core.os.'),
    ('android.support.v4.text.', 'androidx.core.text.'),
    ('android.support.v4.provider.DocumentFile', 'androidx.documentfile.provider.DocumentFile'),
    ('android.support.v4.provider.', 'androidx.core.provider.'),
    ('android.support.v4.hardware.', 'androidx.core.hardware.'),
    ('android.support.v4.media.session.', 'androidx.media.session.'),
    ('android.support.v4.media.', 'androidx.media.'),
    ('android.support.v4.print.', 'androidx.print.'),
    ('android.support.v4.accessibilityservice.', 'androidx.core.accessibilityservice.'),

    ('android.support.annotation.', 'androidx.annotation.'),
]

TOKEN = re.compile(r'android\.support\.[A-Za-z0-9_.]+')


def rewrite(text):
    def repl(m):
        name = m.group(0)
        for src, dst in RULES:
            if name.startswith(src):
                return dst + name[len(src):]
        return name
    return TOKEN.sub(repl, text)


def main(root):
    changed = 0
    for dirpath, _dirs, files in os.walk(root):
        for fn in files:
            if not fn.endswith(('.java', '.xml')):
                continue
            p = os.path.join(dirpath, fn)
            with open(p, encoding='utf-8', errors='replace') as f:
                orig = f.read()
            if 'android.support.' not in orig:
                continue
            new = rewrite(orig)
            if new != orig:
                with open(p, 'w', encoding='utf-8') as f:
                    f.write(new)
                changed += 1
                print('rewrote', p)
    print('changed %d files' % changed)


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'mobile/android')
