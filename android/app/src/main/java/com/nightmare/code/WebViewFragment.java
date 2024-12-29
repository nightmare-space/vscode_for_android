package com.nightmare.code;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.database.ContentObserver;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.provider.Settings;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;

public class WebViewFragment extends Fragment {

    OrientationListener myOrientoinListener;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        WebView mWebView;
        myOrientoinListener = new OrientationListener(getActivity());
        checkState();
        getContext().getContentResolver().registerContentObserver(
                Settings.System.getUriFor(Settings.System.ACCELEROMETER_ROTATION),
                true,
                new ContentObserver(new Handler()) {
                    @Override
                    public void onChange(boolean selfChange) {
                        checkState();
                    }
                }
        );
        mWebView = new WebView(getContext());
        // 设置 mWebView 为 MatchParent
        ViewGroup.LayoutParams layoutParams = new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
        mWebView.setLayoutParams(layoutParams);
        //访问网页
        WebSettings mWebSettings = mWebView.getSettings();
        //允许使用JS
        mWebSettings.setJavaScriptEnabled(true);
        mWebSettings.setJavaScriptCanOpenWindowsAutomatically(true);
        mWebSettings.setUseWideViewPort(true);
        mWebSettings.setAllowFileAccess(true);
        // 下面这行不写不得行
        mWebSettings.setDomStorageEnabled(true);
        mWebSettings.setDatabaseEnabled(true);
//        mWebSettings.setAppCacheEnabled(true);
        mWebSettings.setLoadWithOverviewMode(true);
        mWebSettings.setDefaultTextEncodingName("utf-8");
        mWebSettings.setLoadsImagesAutomatically(true);
        mWebSettings.setSupportMultipleWindows(true);
        mWebView.addJavascriptInterface(new JavaScriptBridge(getContext()), "Android");
        mWebView.setWebChromeClient(webChromeClient);
        // feat 剪切板内容获取的hook
        mWebView.setWebViewClient(new WebViewClient() {
            @Override
            public void onPageFinished(WebView view, String url) {
                // 注入JavaScript代码
                String jsCode = "const originalReadText = navigator.clipboard.readText; " +
                        "navigator.clipboard.readText = function () { " +
                        "console.log('Intercepted clipboard read'); " +
                        "return Android.getClipboardData(); " +
                        "return originalReadText.call(navigator.clipboard).then(text => { " +
                        "console.log('Clipboard content:', text); " +
                        "return text; " +
                        "}); " +
                        "};";
                view.evaluateJavascript(jsCode, null);
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                //使用WebView加载显示url
                view.loadUrl(url);
                //返回true
                return true;
            }
        });
        mWebView.loadUrl("http://127.0.0.1:20000");
        return mWebView;
    }


    public static class JavaScriptBridge {
        Context mContext;

        JavaScriptBridge(Context c) {
            mContext = c;
        }

        @JavascriptInterface
        public String getClipboardData() {
            ClipboardManager clipboard = (ClipboardManager) mContext.getSystemService(Context.CLIPBOARD_SERVICE);
            ClipData clip = clipboard.getPrimaryClip();
            if (clip != null && clip.getItemCount() > 0) {
                return clip.getItemAt(0).getText().toString();
            }
            return "";
        }
    }

    void checkState() {
        boolean autoRotateOn = (android.provider.Settings.System.getInt(getContext().getContentResolver(), Settings.System.ACCELEROMETER_ROTATION, 0) == 1);
        //检查系统是否开启自动旋转
        if (autoRotateOn) {
            myOrientoinListener.enable();
        } else {
            myOrientoinListener.disable();
        }
    }

    WebChromeClient webChromeClient = new WebChromeClient() {

        //=========多窗口的问题==========================================================
        @Override
        public boolean onCreateWindow(WebView view, boolean isDialog, boolean isUserGesture, Message resultMsg) {
            WebView childView = new WebView(getContext());//Parent WebView cannot host it's own popup window.
            childView.setBackgroundColor(Color.GREEN);
            childView.setWebViewClient(new WebViewClient() {
                @Override
                public boolean shouldOverrideUrlLoading(WebView view, String url) {
                    getContext().startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
                    return true;
                }
            });
            WebView.WebViewTransport transport = (WebView.WebViewTransport) resultMsg.obj;
            transport.setWebView(childView);//setWebView和getWebView两个方法
            resultMsg.sendToTarget();
            return true;
        }
        //=========多窗口的问题==========================================================
    };

    @Override
    public void onStop() {
        super.onStop();
        myOrientoinListener.disable();
    }

}