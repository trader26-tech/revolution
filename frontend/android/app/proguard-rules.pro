# ProGuard/R8 rules for release builds.
#
# AGP 9 turns R8 on by default for `release`, and the default config points at
# this file. Without it `assembleRelease` fails outright with
# "Supplied proguard configuration does not exist", so the file has to be here
# even when it's nearly empty.
#
# Flutter's engine and plugins ship their own consumer rules, so there is very
# little to add. Keep only what R8 can't infer.

# Flutter's embedding is reached reflectively from the generated registrant.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# Don't strip annotations other rules (and plugins) depend on.
-keepattributes *Annotation*

# Keep source/line info so release stack traces stay readable, but hide the
# original file name.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Flutter's embedding always compiles in PlayStoreDeferredComponentManager,
# which references the Play Core split-install API. This app doesn't use
# deferred components, so that library isn't on the classpath and R8 aborts
# with "Missing class com.google.android.play.core...". The references are
# genuinely unreachable here — warn-suppress them rather than pulling in a
# dependency the app never calls.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
