function result = getDefaultUIControlBackgroundColor()
    % Returns the default background color for UI controls.
    % Simplified for MATLAB R2025b+ — the old Windows Classic theme check
    % via ws.winapi.IsAppThemed() is no longer needed.
    result = get(0, 'defaultUIControlBackgroundColor') ;
end
