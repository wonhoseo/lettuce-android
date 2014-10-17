package com.lettuce.android.server.actions;

import com.android.uiautomator.core.*;
import com.lettuce.android.server.*;

import java.util.Map;

public class SetText extends Action {

    public SetText(UiDevice uiDevice) {
        super(uiDevice);
    }

    @Override
    public Result execute(Map<String, Object> arguments) throws UiObjectNotFoundException {
        String textDescription = (String) arguments.get("description");
        String text = (String) arguments.get("text");

        UiObject textField = new UiObject(new UiSelector().description(textDescription));

        if(isUiObjectAvailable(textField, arguments)){
            textField.setText(text);
            uiDevice.pressDPadDown();
            return Result.OK;
        }

        return Result.FAILURE;
    }
}
