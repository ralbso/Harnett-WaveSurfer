classdef InProcessRunner < handle
    % InProcessRunner replaces the old Looper + Refiller satellite processes.
    % It creates DAQ tasks, runs acquisition, calculates stimuli, and delivers
    % data back to the WavesurferModel — all in the main MATLAB process.
    %
    % Usage (from WavesurferModel):
    %   self.Runner_ = ws.InProcessRunner(self) ;
    %   self.Runner_.startRun(runConfig) ;
    %   self.Runner_.startSweep(sweepIndex) ;
    %   % ...data arrives via callbacks to model.samplesAcquired()...
    %   self.Runner_.stopRun() ;
    %   delete(self.Runner_) ;
    
    properties (Access = protected)
        Model_  % back-reference to WavesurferModel
        
        % Task objects (created per-run, destroyed on run end)
        TimedAnalogInputTask_ = []
        TimedDigitalInputTask_ = []
        AnalogOutputTask_ = []
        DigitalOutputTask_ = []
        UntimedDigitalOutputTask_ = []
        
        % Run state
        IsPerformingRun_ = false
        IsPerformingSweep_ = false
        
        % Polling timer
        PollTimer_ = []
        TicId_
        FromRunStartTicId_
        TimeOfLastPoll_
        
        % Cached config (set at run start)
        PrimaryDeviceName_
        IsPrimaryDeviceAPXIDevice_
        AcquisitionSampleRate_
        SweepDuration_
        AcquisitionKeystoneTaskType_
        AcquisitionKeystoneTaskDeviceName_
        StimulationKeystoneTaskType_
        StimulationKeystoneTaskDeviceName_
        
        % Channel config
        ActiveAIDeviceNames_
        ActiveAITerminalIDs_
        ActiveDITerminalIDs_
        ActiveAODeviceNames_
        ActiveAOTerminalIDs_
        ActiveDOTerminalIDs_
        AIChannelScales_
        
        % Trigger config
        TriggerDeviceName_
        TriggerPFIID_
        TriggerEdge_
        
        % Sweep tracking
        NScansAcquiredSoFarThisSweep_ = 0
    end
    
    methods
        function self = InProcessRunner(model)
            self.Model_ = model ;
            self.TicId_ = tic() ;
        end
        
        function delete(self)
            self.destroyTasks_() ;
            self.destroyTimer_() ;
            self.Model_ = [] ;
        end
        
        function [scalingCoefficients, clockAtRunStart] = startRun(self, config)
            % config is a struct with all the parameters needed to set up tasks.
            % Returns scaling coefficients and clock time (for backward compatibility).
            
            self.PrimaryDeviceName_ = config.PrimaryDeviceName ;
            self.IsPrimaryDeviceAPXIDevice_ = config.IsPrimaryDeviceAPXIDevice ;
            self.AcquisitionSampleRate_ = config.AcquisitionSampleRate ;
            self.SweepDuration_ = config.SweepDuration ;
            self.AcquisitionKeystoneTaskType_ = config.AcquisitionKeystoneTaskType ;
            self.AcquisitionKeystoneTaskDeviceName_ = config.AcquisitionKeystoneTaskDeviceName ;
            self.StimulationKeystoneTaskType_ = config.StimulationKeystoneTaskType ;
            self.StimulationKeystoneTaskDeviceName_ = config.StimulationKeystoneTaskDeviceName ;
            self.ActiveAIDeviceNames_ = config.ActiveAIDeviceNames ;
            self.ActiveAITerminalIDs_ = config.ActiveAITerminalIDs ;
            self.ActiveDITerminalIDs_ = config.ActiveDITerminalIDs ;
            self.ActiveAODeviceNames_ = config.ActiveAODeviceNames ;
            self.ActiveAOTerminalIDs_ = config.ActiveAOTerminalIDs ;
            self.ActiveDOTerminalIDs_ = config.ActiveDOTerminalIDs ;
            self.AIChannelScales_ = config.AIChannelScales ;
            self.TriggerDeviceName_ = config.TriggerDeviceName ;
            self.TriggerPFIID_ = config.TriggerPFIID ;
            self.TriggerEdge_ = config.TriggerEdge ;
            
            % Create acquisition tasks
            self.TimedAnalogInputTask_ = ...
                ws.AITask('WaveSurfer AI Task', ...
                          self.PrimaryDeviceName_, ...
                          self.IsPrimaryDeviceAPXIDevice_, ...
                          self.ActiveAIDeviceNames_, ...
                          self.ActiveAITerminalIDs_, ...
                          self.AcquisitionSampleRate_, ...
                          self.SweepDuration_, ...
                          self.AcquisitionKeystoneTaskType_, ...
                          self.AcquisitionKeystoneTaskDeviceName_, ...
                          self.TriggerDeviceName_, ...
                          self.TriggerPFIID_, ...
                          self.TriggerEdge_) ;
                      
            self.TimedDigitalInputTask_ = ...
                ws.DITask('WaveSurfer DI Task', ...
                          self.PrimaryDeviceName_, ...
                          self.IsPrimaryDeviceAPXIDevice_, ...
                          self.ActiveDITerminalIDs_, ...
                          self.AcquisitionSampleRate_, ...
                          self.SweepDuration_, ...
                          self.AcquisitionKeystoneTaskType_, ...
                          self.AcquisitionKeystoneTaskDeviceName_, ...
                          self.TriggerDeviceName_, ...
                          self.TriggerPFIID_, ...
                          self.TriggerEdge_) ;
            
            % Create stimulation tasks if needed
            if ~isempty(self.ActiveAOTerminalIDs_)
                self.AnalogOutputTask_ = ...
                    ws.AOTask('WaveSurfer AO Task', ...
                              self.PrimaryDeviceName_, ...
                              self.IsPrimaryDeviceAPXIDevice_, ...
                              self.ActiveAODeviceNames_, ...
                              self.ActiveAOTerminalIDs_, ...
                              self.AcquisitionSampleRate_, ...
                              self.StimulationKeystoneTaskType_, ...
                              self.StimulationKeystoneTaskDeviceName_, ...
                              self.TriggerDeviceName_, ...
                              self.TriggerPFIID_, ...
                              self.TriggerEdge_) ;
            end
            
            if ~isempty(self.ActiveDOTerminalIDs_)
                self.DigitalOutputTask_ = ...
                    ws.DOTask('WaveSurfer DO Task', ...
                              self.PrimaryDeviceName_, ...
                              self.IsPrimaryDeviceAPXIDevice_, ...
                              self.ActiveDOTerminalIDs_, ...
                              self.AcquisitionSampleRate_, ...
                              self.StimulationKeystoneTaskType_, ...
                              self.StimulationKeystoneTaskDeviceName_, ...
                              self.TriggerDeviceName_, ...
                              self.TriggerPFIID_, ...
                              self.TriggerEdge_) ;
            end
            
            % Return the scaling coefficients and clock (for backward compat with Logging)
            scalingCoefficients = self.TimedAnalogInputTask_.ScalingCoefficients ;
            clockAtRunStart = clock() ;
            
            % Create the polling timer
            pollInterval = 0.01 ;  % 10 ms — fast enough for responsive display
            self.PollTimer_ = timer('ExecutionMode', 'fixedSpacing', ...
                                    'Period', pollInterval, ...
                                    'TimerFcn', @(~,~) self.pollForData_(), ...
                                    'ErrorFcn', @(~,evt) self.timerError_(evt)) ;
            
            self.FromRunStartTicId_ = tic() ;
            self.IsPerformingRun_ = true ;
        end
        
        function startSweep(self, sweepIndex) %#ok<INUSD>
            % Prepare and start a single sweep.
            % Stimulus data should already be loaded via loadStimulusData().
            
            self.NScansAcquiredSoFarThisSweep_ = 0 ;
            
            % Start output tasks first (they'll wait for trigger)
            if ~isempty(self.DigitalOutputTask_)
                self.DigitalOutputTask_.start() ;
            end
            if ~isempty(self.AnalogOutputTask_)
                self.AnalogOutputTask_.start() ;
            end
            
            % Start input tasks (reverse order so primary starts last)
            self.TimedDigitalInputTask_.start() ;
            self.TimedAnalogInputTask_.start() ;
            
            self.TimeOfLastPoll_ = toc(self.TicId_) ;
            self.IsPerformingSweep_ = true ;
            
            % Start the polling timer
            start(self.PollTimer_) ;
        end
        
        function loadStimulusData(self, analogData, digitalData)
            % Preload stimulus waveforms into the output tasks.
            if ~isempty(self.AnalogOutputTask_) && ~isempty(analogData)
                self.AnalogOutputTask_.setChannelData(analogData) ;
            end
            if ~isempty(self.DigitalOutputTask_) && ~isempty(digitalData)
                self.DigitalOutputTask_.setChannelData(digitalData) ;
            end
        end
        
        function stopSweep(self)
            if self.IsPerformingSweep_
                self.destroyTimer_() ;
                self.stopAllTasks_() ;
                self.IsPerformingSweep_ = false ;
            end
        end
        
        function stopRun(self)
            self.stopSweep() ;
            self.destroyTasks_() ;
            self.IsPerformingRun_ = false ;
        end
        
        function result = isSweepDone(self)
            if ~self.IsPerformingSweep_
                result = true ;
                return
            end
            aiDone = self.TimedAnalogInputTask_.isDone() ;
            diDone = self.TimedDigitalInputTask_.isDone() ;
            result = aiDone && diDone ;
        end
        
        function result = isOutputDone(self)
            aoDone = isempty(self.AnalogOutputTask_) || self.AnalogOutputTask_.isDone() ;
            doDone = isempty(self.DigitalOutputTask_) || self.DigitalOutputTask_.isDone() ;
            result = aoDone && doDone ;
        end
    end
    
    methods (Access = protected)
        function pollForData_(self)
            % Called by the timer. Reads available data and delivers it to the model.
            if ~self.IsPerformingSweep_
                return
            end
            
            try
                timeSinceSweepStart = toc(self.TicId_) - self.TimeOfLastPoll_ ;
                
                % Read analog data
                isAtLeastOneActiveAI = ~isempty(self.ActiveAITerminalIDs_) ;
                if isAtLeastOneActiveAI
                    [analogData, timeSinceRunStartAtStartOfData] = ...
                        self.TimedAnalogInputTask_.readData([], timeSinceSweepStart, self.FromRunStartTicId_) ;
                    nScans = size(analogData, 1) ;
                    digitalData = ...
                        self.TimedDigitalInputTask_.readData(nScans, timeSinceSweepStart, self.FromRunStartTicId_) ;
                else
                    [digitalData, timeSinceRunStartAtStartOfData] = ...
                        self.TimedDigitalInputTask_.readData([], timeSinceSweepStart, self.FromRunStartTicId_) ;
                    nScans = size(digitalData, 1) ;
                    analogData = zeros(nScans, 0) ;
                end
                
                self.TimeOfLastPoll_ = toc(self.TicId_) ;
                
                % Deliver data to the model
                if nScans > 0
                    self.Model_.samplesAcquired(self.NScansAcquiredSoFarThisSweep_, ...
                                                analogData, ...
                                                digitalData, ...
                                                timeSinceRunStartAtStartOfData) ;
                    self.NScansAcquiredSoFarThisSweep_ = self.NScansAcquiredSoFarThisSweep_ + nScans ;
                end
                
                % Check if sweep is done
                if self.isSweepDone()
                    stop(self.PollTimer_) ;
                    self.IsPerformingSweep_ = false ;
                    self.Model_.looperCompletedSweep() ;
                end
            catch me
                % If something goes wrong during polling, stop and report
                stop(self.PollTimer_) ;
                self.IsPerformingSweep_ = false ;
                warning('ws:pollError', 'Error during data polling: %s', me.message) ;
            end
        end
        
        function timerError_(self, evt) %#ok<INUSD>
            warning('ws:timerError', 'Timer error during data acquisition') ;
            self.IsPerformingSweep_ = false ;
        end
        
        function stopAllTasks_(self)
            if ~isempty(self.TimedAnalogInputTask_)
                try self.TimedAnalogInputTask_.stop() ; catch, end
            end
            if ~isempty(self.TimedDigitalInputTask_)
                try self.TimedDigitalInputTask_.stop() ; catch, end
            end
            if ~isempty(self.AnalogOutputTask_)
                try self.AnalogOutputTask_.stop() ; catch, end
            end
            if ~isempty(self.DigitalOutputTask_)
                try self.DigitalOutputTask_.stop() ; catch, end
            end
        end
        
        function destroyTasks_(self)
            self.stopAllTasks_() ;
            delete(self.TimedAnalogInputTask_) ;
            self.TimedAnalogInputTask_ = [] ;
            delete(self.TimedDigitalInputTask_) ;
            self.TimedDigitalInputTask_ = [] ;
            delete(self.AnalogOutputTask_) ;
            self.AnalogOutputTask_ = [] ;
            delete(self.DigitalOutputTask_) ;
            self.DigitalOutputTask_ = [] ;
        end
        
        function destroyTimer_(self)
            if ~isempty(self.PollTimer_)
                if strcmp(self.PollTimer_.Running, 'on')
                    stop(self.PollTimer_) ;
                end
                delete(self.PollTimer_) ;
                self.PollTimer_ = [] ;
            end
        end
    end
    
end
