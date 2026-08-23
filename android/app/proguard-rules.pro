# WorkManager reflectively instantiates its Room-generated database
# implementation and any Worker subclass by name — R8 must not
# strip/rename these or their constructors, or WorkManager crashes on
# app startup (NoSuchMethodException: WorkDatabase_Impl.<init>()) or
# when a job actually runs. This project's own AppClassificationWorker /
# DomainClassificationWorker (android/app/.../ai/) are covered by the
# ListenableWorker rule below.
-keep class androidx.work.** { *; }
-keep class * extends androidx.room.RoomDatabase
-keep class **_Impl { *; }
-keep class * extends androidx.work.ListenableWorker
-keepclassmembers class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
