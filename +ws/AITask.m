classdef AITask < handle
    % Analog Input Task using MATLAB's native Data Acquisition Toolbox.
    % Replaces the old +dabs-based implementation.
    %
    % KEY CHANGE: readData() now returns DOUBLE data in volts, not int16 ADC counts.
    % Downstream code that previously called ws.scaledDoubleAnalogDataFromRaw()
    % should now just divide by channelScales directly:
    %   scaledData = voltData ./ channelScales
    
    properties (Dependent = true)
        ScalingCoefficients
    end
    
    properties (Access = protected)  
        ChannelCount_ = 0
        SampleRate_ = 20000
        DesiredSweepDuration_ = 1     % Seconds
        ScalingCoefficients_
        DaqDevice_ = []               % MATLAB daq DataAcquisition object, or empty if zero channels
        TicId_
        TimeAtLastRead_
        TimeAtTaskStart_
        NScansReadSoFar_
        NScansExpectedCache_
        CachedFinalScanTime_
    end    
    
    methods
        function self = AITask(taskName, primaryDeviceName, isPrimaryDeviceAPXIDevice, deviceNamePerChannel, terminalIDPerChannel, ...
                               sampleRate, desiredSweepDuration, ...
                               keystoneTaskType, keystoneTaskDeviceName, ...
                               triggerDeviceNameIfKeystone, triggerPFIIDIfKeystone, triggerEdgeIfKeystone) %#ok<INUSL>
                           
            nChannels = length(terminalIDPerChannel) ;
            self.ChannelCount_ = nChannels ;
            self.SampleRate_ = sampleRate ;            
            self.DesiredSweepDuration_ = desiredSweepDuration ;
            self.TicId_ = tic() ;
            
            if nChannels > 0
                % Create the daq device
                self.DaqDevice_ = daq("ni") ;
                self.DaqDevice_.Rate = sampleRate ;
                
                % Add AI voltage channels (differential mode)
                for iChannel = 1:nChannels
                    deviceName = deviceNamePerChannel{iChannel} ;
                    terminalID = terminalIDPerChannel(iChannel) ;
                    channelID = sprintf("ai%d", terminalID) ;
                    ch = addinput(self.DaqDevice_, deviceName, channelID, "Voltage") ;
                    ch.TerminalConfig = "Differential" ;
                    ch.Range = [-10 10] ;
                end
                
                % Verify the actual rate matches what we requested
                if self.DaqDevice_.Rate ~= sampleRate
                    error('ws:sampleClockRateNotEqualToDesiredClockRate', ...
                          'Unable to set the DAQ sample rate to the desired sampling rate (requested %g, got %g)', ...
                          sampleRate, self.DaqDevice_.Rate) ;
                end
                
                % Configure triggering
                triggerTerminalName = '' ;
                triggerEdge = 'rising' ;
                if isequal(keystoneTaskType, 'di')
                    triggerTerminalName = sprintf('%s/di/StartTrigger', keystoneTaskDeviceName) ;
                elseif isequal(keystoneTaskType, 'ai')
                    triggerTerminalName = sprintf('%s/PFI%d', triggerDeviceNameIfKeystone, triggerPFIIDIfKeystone) ;
                    triggerEdge = triggerEdgeIfKeystone ;
                end
                
                if ~isempty(triggerTerminalName)
                    addtrigger(self.DaqDevice_, "Digital", "StartTrigger", ...
                               triggerTerminalName, "External") ;
                end
                
                % Store approximate scaling coefficients for data file metadata
                % (The daq interface returns pre-scaled volts, so these are just for reference)
                voltsPerCount = 20.0 / 65536.0 ;
                self.ScalingCoefficients_ = zeros(4, nChannels) ;
                self.ScalingCoefficients_(2, :) = voltsPerCount ;
            else
                self.DaqDevice_ = [] ;
                self.ScalingCoefficients_ = [] ;
            end
        end
        
        function delete(self)
            if ~isempty(self.DaqDevice_)
                try
                    stop(self.DaqDevice_) ;
                catch
                end
                delete(self.DaqDevice_) ;
            end
            self.DaqDevice_ = [] ;
        end
        
        function start(self)
            if isempty(self.DaqDevice_)
                self.CachedFinalScanTime_ = ws.finalScanTimeFromScanRateAndDesiredDuration(self.SampleRate_, self.DesiredSweepDuration_) ;
                self.NScansExpectedCache_ = ws.nScansFromScanRateAndDesiredDuration(self.SampleRate_, self.DesiredSweepDuration_) ;
                self.NScansReadSoFar_ = 0 ;                    
                timeNow = toc(self.TicId_) ;
                self.TimeAtTaskStart_ = timeNow ;                    
                self.TimeAtLastRead_ = timeNow ;
            else
                start(self.DaqDevice_, "Duration", seconds(self.DesiredSweepDuration_)) ;
                timeNow = toc(self.TicId_) ;
                self.TimeAtLastRead_ = timeNow ;
            end
        end
        
        function stop(self)
            if ~isempty(self.DaqDevice_)
                stop(self.DaqDevice_) ;
            end
        end
        
        function result = isDone(self)
            if isempty(self.DaqDevice_)
                if isinf(self.DesiredSweepDuration_)
                    result = false ;
                else
                    timeNow = toc(self.TicId_) ;
                    durationSoFar = timeNow - self.TimeAtTaskStart_ ;                    
                    result = durationSoFar > self.CachedFinalScanTime_ ;
                end
            else
                result = ~self.DaqDevice_.Running ;
            end            
        end
        
        function value = get.ScalingCoefficients(self)
            value = self.ScalingCoefficients_ ;
        end
        
        function [data, timeSinceRunStartAtStartOfData] = readData(self, nScansToRead, timeSinceSweepStart, fromRunStartTicId) %#ok<INUSL>
            % Returns data as DOUBLE matrix (nScans x nChannels) in VOLTS.
            % This is a change from the old implementation which returned int16.
            timeSinceRunStartNow = toc(fromRunStartTicId) ;
            
            if isempty(self.DaqDevice_)
                % Zero active channels — fake acquisition
                if isempty(nScansToRead)
                    timeNow = toc(self.TicId_) ;                        
                    nScansPossibleByTime = round((timeNow - self.TimeAtLastRead_) * self.SampleRate_) ;                        
                    nScansPossibleByReads = self.NScansExpectedCache_ - self.NScansReadSoFar_ ;
                    nScans = min(nScansPossibleByTime, nScansPossibleByReads) ;
                    data = zeros(nScans, 0) ;
                    self.TimeAtLastRead_ = timeNow ;
                else
                    timeNow = toc(self.TicId_) ;                        
                    data = zeros(nScansToRead, 0) ;
                    self.TimeAtLastRead_ = timeNow ;
                end
            else
                if isempty(nScansToRead)
                    % Read all available data
                    data = read(self.DaqDevice_, "all") ;
                else
                    data = read(self.DaqDevice_, nScansToRead) ;
                end
                % read() returns a timetable in newer MATLAB. Convert to matrix.
                if istimetable(data)
                    data = data{:,:} ;  % extract double matrix from timetable
                end
            end
            
            nScans = size(data, 1) ;
            timeSinceRunStartAtStartOfData = timeSinceRunStartNow - nScans / self.SampleRate_ ;
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end
    end
    
end
