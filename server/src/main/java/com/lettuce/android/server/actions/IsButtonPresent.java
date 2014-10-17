package com.lettuce.android.server.actions;

import com.android.uiautomator.core.*;
import com.lettuce.android.server.*;

import java.util.Map;

public class IsButtonPresent extends Action {
    public IsButtonPresent(UiDevice uiDevice) {
        super(uiDevice);
    }

    @Override
    public Result execute(Map<String, Object> arguments) throws UiObjectNotFoundException {
        String text = (String) arguments.get("text");
        UiObject textView = new UiObject(new UiSelector().className(android.widget.Button.class.getName()).textContains(text));
        return isUiObjectAvailable(textView, arguments) ? Result.OK : Result.FAILURE;
    }
}
