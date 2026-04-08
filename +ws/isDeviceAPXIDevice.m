function result = isDeviceAPXIDevice(deviceName) 
    % Determine if an NI device is a PXI/PXIe device.
    % Uses the modern Data Acquisition Toolbox instead of +dabs.
    if isempty(deviceName) ,
        result = false ;
        return
    end
    try
        devices = daqlist("ni") ;
        matchRows = devices(strcmp(devices.DeviceID, deviceName), :) ;
        if isempty(matchRows) ,
            result = false ;
        else
            % Check the model name for PXI/PXIe indicators
            model = matchRows.Model{1} ;
            result = contains(model, 'PXI', 'IgnoreCase', true) ;
        end
    catch me %#ok<NASGU>
        result = false ;
    end
end
