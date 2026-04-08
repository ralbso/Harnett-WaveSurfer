classdef CounterTriggerTask < handle
    % Counter-based trigger generation using MATLAB's native DAQ Toolbox.
    % Generates a pulse train on a counter output, exported to a PFI terminal,
    % for use as a trigger source.
        
    properties (Access = protected)
        TaskName_ = 'Counter Trigger Task'
        DeviceName_ = ''
        CounterID_ = 0
        RepeatFrequency_ = 1   % Hz
        RepeatCount_ = 1
        PFIID_
        TriggerTerminalName_
        DaqDevice_ = []        
    end

    methods
        function self = CounterTriggerTask(taskName, referenceClockSource, referenceClockRate, deviceName, counterID, ...
                                           repeatFrequency, repeatCount, pfiID, triggerTerminalName) %#ok<INUSL>
            self.TaskName_ = taskName ;
            self.DeviceName_ = deviceName ;
            self.CounterID_ = counterID ;
            self.RepeatFrequency_ = repeatFrequency ;
            self.RepeatCount_ = repeatCount ;
            self.PFIID_ = pfiID ;
            self.TriggerTerminalName_ = triggerTerminalName ;
            
            % Create daq with counter output
            self.DaqDevice_ = daq("ni") ;
            counterName = sprintf("ctr%d", counterID) ;
            addoutput(self.DaqDevice_, deviceName, counterName, "PulseGeneration") ;
            
            % Configure the pulse parameters
            ch = self.DaqDevice_.Channels(1) ;
            ch.Frequency = repeatFrequency ;
            ch.DutyCycle = 0.5 ;
            ch.InitialDelay = 0 ;
            
            % Configure trigger
            if ~isempty(triggerTerminalName)
                addtrigger(self.DaqDevice_, "Digital", "StartTrigger", ...
                           triggerTerminalName, "External") ;
            end
        end
        
        function delete(self)
            try
                self.stop() ;
            catch
            end
            if ~isempty(self.DaqDevice_)
                delete(self.DaqDevice_) ;
            end
            self.DaqDevice_ = [] ;
        end
        
        function start(self)
            if ~isempty(self.DaqDevice_)
                if isinf(self.RepeatCount_)
                    start(self.DaqDevice_, "continuous") ;
                else
                    start(self.DaqDevice_, "NumScans", self.RepeatCount_) ;
                end
            end
        end
        
        function stop(self)
            if ~isempty(self.DaqDevice_) && isvalid(self.DaqDevice_)
                if self.DaqDevice_.Running
                    stop(self.DaqDevice_) ;
                end
            end
        end
        
        function result = isDone(self)
            if isempty(self.DaqDevice_)
                result = true ;
            else
                result = ~self.DaqDevice_.Running ;
            end
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end
    end

end
