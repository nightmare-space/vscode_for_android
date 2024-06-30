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
        flutterEngine.getDartExecutor().executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
        );
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "vscode_channel").setMethodCallHandler((call, result) -> {
            new Thread(() -> {
                try {
                    Intent intent = new Intent(MainActivity.this, VSCodePage.class);
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    intent.putExtra("args", call.method);
                    startActivity(intent);
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }).start();
        });
        GeneratedPluginRegistrant.registerWith(flutterEngine);
        FlutterEngineCache.getInstance().put("my_engine_id", flutterEngine);
        if (flutterFragment == null) {
            flutterFragment = FlutterFragment.withCachedEngine("my_engine_id").build();
        }
        fragmentManager
                .beginTransaction()
                .add(
                        R.id.fl_container,
                        flutterFragment,
                        TAG_FLUTTER_FRAGMENT
                )
                .commit();
        // Create and attach a FlutterFragment if one does not exist.

//        new ADManage().initSDK(this, "1635623807981195265", new ADInitListener() {
//            @Override
//            public void onSuccess() {
//                Log.e("Lori", "ad_init 成功");
////                showBannerAD();
////                showAppOpenSplashAD();
//                showAppSplashAD();
//            }
//
//            @Override
//            public void onError(int code, String message) {
//                Log.e("Lori", "ad_init" + message);
//            }
//        });

    }

    public void showAppSplashAD() {
//        ViewGroup splash_container = findViewById(R.id.splash_container);
//        new SuperSplashAD(mContext, splash_container, new SuperSplashADListener() {
//            @Override
//            public void onError(Object error) {
//
//            }
//
//            @Override
//            public void onAdLoad() {
//
//            }
//
//            @Override
//            public void onADShow() {
//
//            }
//
//            @Override
//            public void onADClicked() {
//
//            }
//
//            @Override
//            public void onADDismissed() {
//                splash_container.removeAllViews();
//                splash_container.setVisibility(View.GONE);
//                // Toast.makeText(mContext, "开屏广告结束,请将程序跳转到主界面", Toast.LENGTH_SHORT).show();
//                fragmentManager
//                        .beginTransaction()
//                        .add(
//                                R.id.fl_container,
//                                flutterFragment,
//                                TAG_FLUTTER_FRAGMENT
//                        )
//                        .commit();
//            }
//
//            @Override
//            public void onAdTypeNotSupport() {
//
//            }
//
//        });
    }

    public void showFullScreenDialog() {
//        SuperFullUnifiedInterstitialAD ad = new SuperFullUnifiedInterstitialAD((Activity) mContext, new SuperFullUnifiedInterstitialADListener() {
//
//            @Override
//            public void onError(Object error) {
//                Log.e("~~~~", "onError");
//            }
//
//            @Override
//            public void onAdLoad() {
//                Log.e("~~~~", "onAdLoad");
//            }
//
//            @Override
//            public void onAdClicked() {
//                Log.e("~~~~", "onAdClicked");
//            }
//
//            @Override
//            public void onAdShow() {
//                Log.e("~~~~", "onAdShow");
//            }
//
//            @Override
//            public void onADClosed() {
//                Log.e("~~~~", "onADClosed");
//
//            }
//
//            @Override
//            public void onRenderSuccess() {
//                Log.e("~~~~", "onRenderSuccess");
//
//            }
//
//            @Override
//            public void onRenderFail() {
//                Log.e("~~~~", "onRenderFail");
//            }
//
//            @Override
//            public void onAdTypeNotSupport() {
//                Log.e("~~~~", "onAdTypeNotSupport");
//            }
//        });
    }

    public void showHalfDialog() {
//        SuperHalfUnifiedInterstitialAD ad = new SuperHalfUnifiedInterstitialAD((Activity) mContext, new SuperHalfUnifiedInterstitialADListener() {
//            @Override
//            public void onError(Object error) {
//                Log.e("~~~~~", "onError" + error.toString());
//            }
//
//            @Override
//            public void onAdLoad() {
//                Log.e("~~~~~", "onAdLoad");
//            }
//
//            @Override
//            public void onAdClicked() {
//                Log.e("~~~~~", "onAdClicked");
//            }
//
//            @Override
//            public void onAdShow() {
//                Log.e("~~~~~", "onAdShow");
//            }
//
//            @Override
//            public void onADClosed() {
//                Log.e("~~~~~", "onADClosed");
//            }
//
//            @Override
//            public void onRenderSuccess() {
//                Log.e("~~~~~", "onRenderSuccess");
//            }
//
//            @Override
//            public void onRenderFail() {
//                Log.e("~~~~~", "onRenderFail");
//            }
//
//            @Override
//            public void onAdTypeNotSupport() {
//
//            }
//        });
    }

    public void showBannerAD() {
        ViewGroup banner_container = findViewById(R.id.fl_container);
//        SuperBannerAD ad = new SuperBannerAD((Activity) mContext, banner_container, new SuperUnifiedBannerADListener() {
//            @Override
//            public void onError(Object var1) {
//                Log.e("~~~~", "onError");
//            }
//
//            @Override
//            public void onADLoad() {
//                Log.e("~~~~", "onADLoad");
//            }
//
//            @Override
//            public void onADShow() {
//                Log.e("~~~~", "onADShow");
//            }
//
//            @Override
//            public void onADClick() {
//                Log.e("~~~~", "onADClick");
//            }
//
//            @Override
//            public void onADClose() {
//                Log.e("~~~~", "onADClose");
//                banner_container.removeAllViews();
//            }
//
//            @Override
//            public void onRenderFail() {
//                Log.e("~~~~", "onRenderFail");
//            }
//
//            @Override
//            public void onRenderSuccess() {
//                Log.e("~~~~", "onRenderSuccess");
//            }
//
//            @Override
//            public void onAdTypeNotSupport() {
//
//            }
//        });
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
        flutterFragment.onBackPressed();
    }

    @Override
    public void onRequestPermissionsResult(
            int requestCode,
            @NonNull String[] permissions,
            @NonNull int[] grantResults
    ) {
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
//    @Override
//    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
//        super.configureFlutterEngine(flutterEngine);
//        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "vscode_channel").setMethodCallHandler((call, result) -> {
//            new Thread(() -> {
//                try {
//                    Intent intent = new Intent(MainActivity.this, VSCodePage.class);
//                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
//                    intent.putExtra("args", call.method);
//                    startActivity(intent);
//                } catch (Exception e) {
//                    e.printStackTrace();
//                }
//            }).start();
//        });
//    }

}
