package com.nightmare.code;

import android.content.Intent;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {


    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
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
    }

}
