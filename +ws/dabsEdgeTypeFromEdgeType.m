function dabsEdgeType = dabsEdgeTypeFromEdgeType(edgeType)
    % DEPRECATED: This function is no longer needed with the native DAQ Toolbox.
    % The native `addtrigger()` function accepts 'rising'/'falling' directly.
    % Kept for backward compatibility with any code that still references DAQmx constants.
    switch edgeType
        case 'rising'
            dabsEdgeType = 'DAQmx_Val_Rising' ;
        case 'falling'
            dabsEdgeType = 'DAQmx_Val_Falling' ;
        otherwise
            dabsEdgeType = [] ;
    end
end
