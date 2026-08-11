package dev.redroid.arm64smoke;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.widget.TextView;

public final class MainActivity extends Activity {
    private static final String TAG = "RedroidArm64Smoke";

    static {
        System.loadLibrary("redroid_arm64_smoke");
    }

    private static native String nativeMessage();

    @Override
    public void onCreate(Bundle state) {
        super.onCreate(state);
        String message = nativeMessage();
        Log.i(TAG, message);
        TextView text = new TextView(this);
        text.setText(message);
        text.setTextSize(24);
        setContentView(text);
    }
}
