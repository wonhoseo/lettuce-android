package com.lettuce.android.server.actions;

import com.android.uiautomator.core.UiDevice;
import com.android.uiautomator.core.UiObjectNotFoundException;
import com.lettuce.android.server.Action;
import com.lettuce.android.server.Result;

import java.util.Map;

public class IsRegexMatchPresent extends Action {

    public IsRegexMatchPresent(UiDevice uiDevice){
        super(uiDevice);
    }

    @Override
    public Result execute(Map<String, Object> arguments) throws UiObjectNotFoundException {
        return isUiObjectAvailable(getUiObject(arguments), arguments) ? Result.OK : Result.FAILURE;
    }
}
