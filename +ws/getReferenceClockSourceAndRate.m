function [source, rate] = getReferenceClockSourceAndRate(deviceName, primaryDeviceName, isPrimaryDeviceAPXIDevice) 
    % Returns the reference clock source and rate for multi-device synchronization.
    %
    % NOTE: With the native Data Acquisition Toolbox, reference clock configuration
    % is handled automatically. This function is kept for backward compatibility
    % with callers that pass these values to FiniteOutputTask and CounterTriggerTask,
    % but the new Task implementations ignore these parameters.
    if isPrimaryDeviceAPXIDevice
        source = 'PXIe_CLK100' ;
        rate = 100e6 ;
    else
        if isequal(deviceName, primaryDeviceName)
            source = 'OnboardClock' ;
        else
            source = sprintf('/%s/10MHzRefClock', primaryDeviceName) ;
        end
        rate = 10e6 ;
    end
end
