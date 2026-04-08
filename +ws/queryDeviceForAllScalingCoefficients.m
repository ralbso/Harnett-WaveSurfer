function scalingCoefficients = queryDeviceForAllScalingCoefficients(deviceName) 
    % Returns approximate scaling coefficients for all AI terminals on the device.
    %
    % With the modern DAQ Toolbox, data is returned pre-scaled as doubles,
    % so these coefficients are primarily used for backward compatibility 
    % with the HDF5 data file format when raw int16 data is stored.
    %
    % For NI X-series 16-bit ADCs with +/-10V range:
    %   volts = c0 + c1*counts + c2*counts^2 + c3*counts^3
    % where the dominant term is the linear coefficient c1 ≈ 20/65536.
    %
    % Returns: nCoefficients x nChannels matrix (low-order coefficients first)
    
    nSingleEndedAITerminals = ws.getNumberOfSingleEndedAITerminalsFromDevice(deviceName) ;
    
    if nSingleEndedAITerminals == 0
        scalingCoefficients = [] ;
        return
    end
    
    % Use 4 polynomial coefficients (standard for NI X-series)
    % These are approximate values for a ±10V range, 16-bit ADC.
    % The actual per-channel calibration from NI is more precise, but
    % since the daq toolbox handles scaling internally, these are only
    % used for data file metadata.
    nCoefficients = 4 ;
    scalingCoefficients = zeros(nCoefficients, nSingleEndedAITerminals) ;
    
    % Linear coefficient: volts_per_count = voltage_range / adc_range
    % For ±10V on 16-bit signed: 20 / 65536 ≈ 3.0518e-4
    voltsPerCount = 20.0 / 65536.0 ;
    scalingCoefficients(2, :) = voltsPerCount ;  % row 2 = linear coefficient
    % Rows 1, 3, 4 = zero (offset, quadratic, cubic terms)
end
