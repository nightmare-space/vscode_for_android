package com.nightmare.code;

import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.fragment.app.FragmentActivity;
import androidx.fragment.app.FragmentManager;

import io.flutter.embedding.android.FlutterFragment;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FragmentActivity {
    FlutterFragment flutterFragment;
    private static final String TAG_FLUTTER_FRAGMENT = "flutter_fragment";
    Context mContext;
    FragmentManager fragmentManager = getSupportFragmentManager();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        mContext = this;
        setContentView(R.layout.my_activity_layout);
        // Attempt to find an existing FlutterFragment,
        // in case this is not the first time that onCreate() was run.
        flutterFragment = (FlutterFragment) fragmentManager.findFragmentByTag(TAG_FLUTTER_FRAGMENT);
        FlutterEngine flutterEngine = new FlutterEngine(this);
        flutterEngine.getDartExecutor().executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault());
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "vscode_channel").setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "open_webview": {
                    runOnUiThread(() -> {
                        fragmentManager.beginTransaction()
                                .replace(R.id.fl_container, new WebViewFragment())
                                .commit();
                        result.success("success");
                    });
                }
                break;
                case "lib_path": {
                    result.success(mContext.getApplicationContext().getApplicationInfo().nativeLibraryDir);
                }
                break;
                default:
                    result.notImplemented();
            }
        });
        GeneratedPluginRegistrant.registerWith(flutterEngine);
        FlutterEngineCache.getInstance().put("my_engine_id", flutterEngine);
        if (flutterFragment == null) {
            flutterFragment = FlutterFragment.withCachedEngine("my_engine_id").build();
        }
        fragmentManager
                .beginTransaction()
                .add(R.id.fl_container, flutterFragment, TAG_FLUTTER_FRAGMENT)
                .commit();
    }


    @Override
    public void onPostResume() {
        super.onPostResume();
        flutterFragment.onPostResume();
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        flutterFragment.onNewIntent(intent);
    }

    @Override
    public void onBackPressed() {
        super.onBackPressed();
        flutterFragment.onBackPressed();
    }

    @Override
    public void onRequestPermissionsResult(
            int requestCode,
            @NonNull String[] permissions,
            @NonNull int[] grantResults
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        flutterFragment.onRequestPermissionsResult(
                requestCode,
                permissions,
                grantResults
        );
    }

    @Override
    public void onUserLeaveHint() {
        flutterFragment.onUserLeaveHint();
    }

    @Override
    public void onTrimMemory(int level) {
        super.onTrimMemory(level);
        flutterFragment.onTrimMemory(level);
    }

}
