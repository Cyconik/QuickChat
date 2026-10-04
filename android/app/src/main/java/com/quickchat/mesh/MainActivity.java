package com.quickchat.mesh;

import android.os.Bundle;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(NativeBleMeshPlugin.class);
        super.onCreate(savedInstanceState);
    }
}
