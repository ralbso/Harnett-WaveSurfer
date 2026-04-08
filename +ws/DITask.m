classdef DITask < handle
    % Digital Input Task using MATLAB's native Data Acquisition Toolbox.
    
    properties (Access = protected)
        DaqDevice_ = []
        TicId_
        TimeAtLastRead_
        TimeAtTaskStart_
        NScansReadSoFar_
        NScansExpectedCache_
        CachedFinalScanTime_
        SampleRate_ = 20000
        DesiredSweepDuration_ = 1
        TerminalIDs_
    end
    
    methods
        function self = DITask(taskName, primaryDeviceName, isPrimaryDeviceAPXIDevice, terminalIDs, ...
                               sampleRate, desiredSweepDuration, ...
                               keystoneTaskType, keystoneTaskDeviceName, ...
                               triggerDeviceNameIfKeystone, triggerPFIIDIfKeystone, triggerEdgeIfKeystone) %#ok<INUSL>
                           
            nChannels = length(terminalIDs) ;
            self.TicId_ = tic() ;
            self.SampleRate_ = sampleRate ;
            self.DesiredSweepDuration_ = desiredSweepDuration ;            
            self.TerminalIDs_ = terminalIDs ;
            
            if nChannels > 0
                self.DaqDevice_ = daq("ni") ;
                self.DaqDevice_.Rate = sampleRate ;
                
                % Add digital input channels (port0 lines)
                for iChannel = 1:nChannels
                    terminalID = terminalIDs(iChannel) ;
                    channelID = sprintf("port0/line%d", terminalID) ;
                    addinput(self.DaqDevice_, primaryDeviceName, channelID, "Digital") ;
                end
                
                % Verify rate
                if self.DaqDevice_.Rate ~= sampleRate
                    error('ws:sampleClockRateNotEqualToDesiredClockRate', ...
                          'Unable to set the DAQ sample rate to the desired sampling rate') ;
                end
                
                % Configure triggering
                triggerTerminalName = '' ;
                if isequal(keystoneTaskType, 'ai')
                    triggerTerminalName = sprintf('%s/ai/StartTrigger', keystoneTaskDeviceName) ;
                elseif isequal(keystoneTaskType, 'di')
                    triggerTerminalName = sprintf('%s/PFI%d', triggerDeviceNameIfKeystone, triggerPFIIDIfKeystone) ;
                end
                
                if ~isempty(triggerTerminalName)
                    addtrigger(self.DaqDevice_, "Digital", "StartTrigger", ...
                               triggerTerminalName, "External") ;
                end
            else
                self.DaqDevice_ = [] ;
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
                    result = (timeNow - self.TimeAtTaskStart_) > self.CachedFinalScanTime_ ;
                end
            else
                result = ~self.DaqDevice_.Running ;
            end            
        end
        
        function [data, timeSinceRunStartAtStartOfData] = readData(self, nScansToRead, timeSinceSweepStart, fromRunStartTicId) %#ok<INUSL>
            % Returns data as a LOGICAL matrix (nScans x nChannels).
            timeSinceRunStartNow = toc(fromRunStartTicId) ;
            
            if isempty(self.DaqDevice_)
                nLines = length(self.TerminalIDs_) ;
                if isempty(nScansToRead)
                    timeNow = toc(self.TicId_) ;                        
                    nScansPossibleByTime = round((timeNow - self.TimeAtLastRead_) * self.SampleRate_) ;                        
                    nScansPossibleByReads = self.NScansExpectedCache_ - self.NScansReadSoFar_ ;
                    nScans = min(nScansPossibleByTime, nScansPossibleByReads) ;
                    data = false(nScans, nLines) ;
                    self.TimeAtLastRead_ = timeNow ;
                else
                    data = false(nScansToRead, nLines) ;
                    self.TimeAtLastRead_ = toc(self.TicId_) ;
                end
            else       
                if isempty(nScansToRead)
                    rawData = read(self.DaqDevice_, "all") ;
                else
                    rawData = read(self.DaqDevice_, nScansToRead) ;
                end
                % Convert timetable to logical matrix
                if istimetable(rawData)
                    rawData = rawData{:,:} ;
                end
                data = logical(rawData) ;
            end
            
            nScans = size(data, 1) ;
            timeSinceRunStartAtStartOfData = timeSinceRunStartNow - nScans / self.SampleRate_ ;
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end
    end
    
end
