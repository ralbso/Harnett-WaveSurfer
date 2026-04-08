function result = getNumberOfCountersFromDevice(deviceName)
    % The number of general-purpose counters (CTRs) on the board.
    % Uses the modern Data Acquisition Toolbox instead of +dabs.
    if isempty(deviceName) ,
        result = 0 ;
        return
    end
    try
        devices = daqlist("ni") ;
        ctrRows = devices(strcmp(devices.DeviceID, deviceName) & ...
                          strcmp(devices.SubsystemType, "CounterOutput"), :) ;
        if isempty(ctrRows) ,
            result = 0 ;
        else
            result = ctrRows.NumChannels(1) ;
        end
    catch me %#ok<NASGU>
        result = 0 ;
    end
end
